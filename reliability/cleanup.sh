oc adm prune images --keep-tag-revisions=3 --keep-younger-than=60m --confirm --registry-url <REPLACE - registry route>
oc adm prune deployments --orphans --keep-complete=5 --keep-failed=1     --keep-younger-than=60m --confirm
oc adm prune builds --orphans --keep-complete=5 --keep-failed=1     --keep-younger-than=60m --confirm
