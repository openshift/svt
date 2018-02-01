oc login -u redhat -p redhat
oc adm prune images --keep-tag-revisions=3 --keep-younger-than=60m --confirm
oc login -u system:admin
oc adm prune deployments --orphans --keep-complete=5 --keep-failed=1     --keep-younger-than=60m --confirm
oc adm prune builds --orphans --keep-complete=5 --keep-failed=1     --keep-younger-than=60m --confirm
