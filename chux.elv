fn find_select_edit {|&base_dir=$pwd file_name|
  nop ?(find $base_dir -name $file_name | fzf --bind 'e:execute(nvim {1} < /dev/tty)')
}

var gcp: = (use-mod ./chux/gcp)[-gcp]
var g: = $gcp:

var java: = (use-mod ./chux/java)[-java]
var j: = $java:

var tasks: = (use-mod ./chux/tasks)[-tasks]
vat t: = $tasks:
