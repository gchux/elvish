use str



fn -run-services-newListClient {|&ctx=$nil &utils=[&]|

  var services-exec~ = $ctx[exec]
  var exec~ = {|&raw-flags=[] &flags=[] @args|
    $services-exec~ &raw-flags=$raw-flags &flags=$flags list $@args
  }

  var methods = [&]

  set methods[exec] = $exec~ 
  set methods[-] = $methods[exec]
  
  put (ns $methods)
}

fn -run {|&cli=$nil &utils=[&]|

  var properties = (make-map [
    [ctx $cli]
  ])
  var services = [&]

  var cli-exec~ = $cli[exec]
  var exec~ = {|&raw-flags=[] &flags=[] @args|
    $cli-exec~ &raw-flags=$raw-flags &flags=$flags services $@args
  }

  set services[list] = {|@args|
   $exec~ list $@args
  }
  set services[ls] = $services[list]

  var -services = (make-map [
    [properties $properties]
    [methods (ns $services)]
    [exec $exec~]
  ])

  set services[newListClient] = {
    put ($-run-services-newListClient~ &ctx=$-services &utils=$utils)
  }

  set services[help] = {
   $exec~ &raw-flags=['--help']
  }
  set services[h] = $services[help]

  var methods = $cli[methods]
  set methods[services:] = (ns $services)
  set methods[svc:] = $methods[services:]

  put $methods
}

var providers = (ns (make-map [
  ['run' $-run~]
]))

fn newClient {|groupOrCommand|
  if (not (has-key $providers $groupOrCommand)) { exit 1 }

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
    gcloud $groupOrCommand $@args $@raw-flags $@-flags
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

  var cli = (make-map [
    [properties $properties]
    [methods $methods]
    [exec $exec~]
    [utils $utils]
  ])

  set methods = ($providers[$groupOrCommand] &cli=$cli &utils=$utils)
  set m = $methods

  set api = (ns $methods)
  put $api
}

var -cli = (ns (make-map [      ^
  ['newClient' $newClient~]     ^
]))
