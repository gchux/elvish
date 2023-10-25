use chux

var -java = [&]

set -java[edit] = {
  chux:find_select_edit '*.java'
}
set -java[e] = $-java['edit']

set -java = (ns $-java)
