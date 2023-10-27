var -gcp = [&]

var -gcurl~ = {|@args| 
  curl -H "Authorization: Bearer "(gcloud auth print-access-token) $@args
}
set -gcp['curl'] = $-gcurl~

var -gidcurl~ = {|@args|
  curl -H "Authorization: Bearer "(gcloud auth print-identity-token) $@args
}
set -gcp['id_curl'] = $-gidcurl~

set -gcp['cli:'] = (use-mod ./gcp/cli)[-cli]

set -gcp = (ns $-gcp)
