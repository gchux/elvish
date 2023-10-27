fn find-select-edit {|&base_dir=$pwd file_name|
  nop ?(find $base_dir -name $file_name ^
          | fzf --bind 'e:execute(nvim {1} < /dev/tty)')
}
var -find-select-edit~ = $find-select-edit~

var -utils = (ns (make-map [                  ^
  ['find-select-edit' $-find-select-edit~]    ^
]))
