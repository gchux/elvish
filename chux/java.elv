use ./utils x

var -java = [&]

set -java[edit] = {
  x:find-select-edit '*.java'
}
set -java[e] = $-java['edit']

set -java = (ns $-java)
