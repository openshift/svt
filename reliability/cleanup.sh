oc login -u redhat -p redhat
oadm prune images --keep-tag-revisions=3 --keep-younger-than=60m --confirm
oc login -u system:admin
oadm prune deployments --orphans --keep-complete=5 --keep-failed=1     --keep-younger-than=60m --confirm
oadm prune builds --orphans --keep-complete=5 --keep-failed=1     --keep-younger-than=60m --confirm
