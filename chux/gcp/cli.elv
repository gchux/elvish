use str
use runtime
use file

var -cmds-json = 'chux/gcp/cli.json'

fn -flagToMethods {|&flag=''|
  var opt = (conj [] (str:split '=' $flag))[0]
  var withoutDashes = (str:trim-left $flag '-')
  var parts = (conj [] (str:split '=' $withoutDashes))
  var flagName = $parts[0]
  var isBoolean = (eq (count $parts) (num 1)) 

  set flag = (make-map [[flag $flag]])
  set flag[opt] = $opt
  set flag[name] = $flagName
  set flag[parts] = $parts
  set flag[isBoolean] = $isBoolean
  set flag[withoutDashes] = $withoutDashes

  var -name = (str:replace '-' '' (str:title $flagName))

  var methods = [&]
  if $isBoolean {
    set flag[value] = $false
    set methods['enable'$-name] = { set flag[value] = $true }
    set methods['disable'$-name] = { set flag[value] = $false }
    set methods['toggle'$-name] = { set flag[value] = (not $flag[value]) }
    set methods['is'$-name] = { put $flag[value] }
  } else {
    set flag[values] = $parts[1]
    set flag[value] = $nil
    set methods['set'$-name] = {|value| set flag[value] = $value }
    set methods['get'$-name] = { put $flag[value] }
  }

  set flag[print] = { pprint (dissoc $flag methods) }
  set methods['print'$-name] = $flag[print]

  set flag[toString] = {
    var value = $flag[value]
    if $value {
      if $isBoolean { put $true $opt } else { 
        put $true (str:join '=' [$opt $value]) 
      }
    } else { put $false $nil }
  }

  set flag[methods] = $methods

  put $flag
}

fn -newClient {|&ctx=[&] &command=[&] &exec~={ fail 'unavailable' }|
  var flags = []

  if (has-key $command _flags_) { 
    set flags = $command[_flags_] 
  }

  var methods = [&]
  var -flags = [&]
  
  each {|flag|
    var -flag = ($-flagToMethods~ &flag=$flag)
    set -flags[$-flag[name]] = $-flag
    var -methods = $-flag[methods]
    each {|method|
      set methods[$method] = $-methods[$method]
    } (conj [] (keys $-methods))
  } $flags
  
  set methods[-printFlags] = {
    each {|flag|
      $-flags[$flag][print]
    } (conj [] (keys $-flags))
  }
  
  var -exec~ = {
    var flags = []
    each {|name|
      var -flag = $-flags[$name]
      var use flag = ($-flag[toString])
      if $use {
        set flags = (conj $flags $flag)
      }
    } (conj [] (keys $-flags))
    $exec~ &flags=$flags
  }

  set methods[-] = $-exec~
  set methods[run] = $-exec~
  set methods[exec] = $-exec~
  
  put (ns $methods)
}

fn -addCommand {|&ctx=[&] &namespace=[] &commands=[&] &command=[&]|
  var commandName = $command[_name_]

  var -exec~ = $ctx[exec];
  var exec~ = {|&flags=[] &raw-flags=[] @args|
    var -namespace = (conj $namespace $commandName)
    $-exec~ &flags=$flags &raw-flags=$raw-flags $@-namespace $@args
  }

  set commands[$commandName] = $exec~
  set commands[$commandName'-new'] = ($-newClient~ &ctx=$ctx &command=$command &exec~=$exec~)

  put $commands 
}

fn -addProvider {|&ctx=$nil &namespace=[] &provider=[&]|
  var commands = $ctx[commands]

  if (has-key $provider commands) {
    each {|command|
      set commands = ($-addCommand~ &ctx=$ctx &namespace=$namespace &commands=$commands &command=$command)
    } $provider[commands]
  }

  if (has-key $provider groups) {
    each {|group|
      var groupName = $group[_name_]
      var groupKey = $groupName':'
      var -namespace = (conj $namespace $groupName)
      var -group = ($-addProvider~ &ctx=$ctx &namespace=$-namespace &provider=$group)
      set commands[$groupKey] = $-group
    } $provider[groups] 
  }

  put (ns $commands)
}

fn newClient {|groupOrCommand|

  var cli-json = (str:join '/' [$runtime:lib-dirs[0] $-cmds-json])

  var namespace = (jq -rcM '._name_' < $cli-json)
  var groups = (jq -cM '.groups[] | ._name_' < $cli-json | jq -srcM | from-json)
  var commands = (jq -cM '.commands[] | ._name_' < $cli-json | jq -srcM | from-json)

  var isGroup = (has-value $groups $groupOrCommand)
  var isCommand = (not (or $isGroup (has-value $commands $groupOrCommand)))

  if (not (or $isCommand $isGroup)) {
    fail (printf "'%s' is neither a command nor a group" $groupOrCommand | slurp) 
  }

  var category = (if $isGroup { put 'groups' } else { put 'command' })

  var cli-json-filter-template = '.%s[] | select(.%s=="%s")'
  var cli-json-filter = (printf $cli-json-filter-template $category '_name_' $groupOrCommand | slurp)
  var provider = (jq -cM $cli-json-filter < $cli-json | from-json)

  var -projectId = (gcloud config get project 2>/dev/null | tr -d '\n' | slurp)

  var properties = [
    &projectId=$-projectId
    &debug=$false
    &trace=$false
    &quiet=$false
  ]
  var p = $properties

  var utils = [&]

  var flagToString~ = {|flag|
    var flag-str = ['--' $flag[name]]
    if (has-key $flag value) {
      set flag-str = (conj $flag-str '=' $flag[value])
    }
    put (str:join '' $flag-str)
  }
  set utils[flagToString] = $flagToString~ 

  var addFlag~ = {|&flags=[] flag|
    if (and (has-key $flag condition) ($flag[condition~])) {
      set flags = (conj $flags ($flagToString~ $flag))
    }
    put $flags
  }
  set utils[addFlag] = $addFlag~ 

  var createFlag~ = {|&condition~=$nil name|
    var flag = (make-map [[name $name]])
    if (not (is $condition~ $nil)) {
      set flag[condition~] = $condition~
    }
    put $flag
  }
  set utils[createFlag] = $createFlag~ 

  var createValueFlag~ = {|&condition~=$nil name value|
    var flag = ($createFlag~ &condition~=$condition~ name)
    set flag[value] = $value;
    put $flag
  }
  set utils[createValueFlag] = $createValueFlag~ 

  var flags~ = {
    var flags = []

    var add~ = {|flag|
      set flags = ($addFlag~ &flags=$flags $flag)
    }

    $add~ ($createValueFlag~ project $p[projectId])
    $add~ ($createValueFlag~ &condition~={ and (not $p[quiet]) $p[debug] } verbosity debug)
    $add~ ($createFlag~ &condition~={ and (not $p[quiet]) $p[trace] } log-http)

    put $flags
  }

  var exec~ = {|&flags=[] &raw-flags=[] @args|
    var -flags = ($flags~)
    gcloud $@args $@raw-flags $@-flags $@flags
  }

  var setDebug~ = {|&enabled=$false|
    set p[quiet] = $false
    set p[debug] = $true
  }
  set utils[setDebug] = $setDebug~

  var setTrace~ = {|&enabled=$false|
    $setDebug~ &enabled=$true
    set p[trace] = $true
  }
  set utils[setTrace] = $setTrace~

  var methods = [&]
  var m = $methods

  var api = $nil

  set methods[help] = {
    $exec~ &raw-flags=['--help']
  }
  set methods[h] = $methods[help]

  set methods[withProjectId] = {|projectId|
    set p[projectId] = $projectId
  }

  set methods[enableDebug] = {
    $setDebug~ &enabled=$true
  }
  set methods[disableDebug] = {
    $setDebug~ &enabled=$false
  }

  set methods[enableTrace] = {
    $setTrace~ &enabled=$true
  }
  set methods[disableTrace] = {
    $setTrace~ &enabled=$false
  }

  set methods[toString] = {
    pprint [
      &properties=$p 
      &methods=[(keys $m)]
    ]
  }
  set methods[str] = $methods[toString]

  set methods[toJSON] = {
    make-map [
      [properties $p] 
      [methods [(keys $m)]]
    ] | to-json
  }

  var ctx = (make-map [
    [properties $properties]
    [commands $methods]
    [exec $exec~]
    [utils $utils]
  ])

  var commands = ($-addProvider~ &ctx=$ctx &namespace=[$groupOrCommand] &provider=$provider)
  set m = $commands
  put $commands
}

var -cli = (ns (make-map [      ^
  ['newClient' $newClient~]     ^
]))
