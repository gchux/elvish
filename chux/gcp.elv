var -gcp = [&]

var -gcurl~ = {|@args| 
  curl -H "Authorization: Bearer "(gcloud auth print-access-token) $@args
}

var -gidcurl~ = {|@args|
  curl -H "Authorization: Bearer "(gcloud auth print-identity-token) $@args
}

set -gcp['curl'] = $-gcurl~
set -gcp['id_curl'] = $-gidcurl~

set -gcp = (ns $-gcp)
