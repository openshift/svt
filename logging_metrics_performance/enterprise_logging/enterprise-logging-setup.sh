### Creat from zero, not idempotent.
set -x
set -e 

echo "This script shouldnt be executed by someone who doesnt understand it :)"
echo "Rather, it documents the steps for setting up enterprise logging to the best of our knoweldge"
echo "Note it isnt idempotent, its probably a good idea to delete logging projects and recreate from zero"
echo "... hit enter to proceed at your own risk !"
read x

oc new-project logging

oc create -f \
/home/cloud-user/openshift-ansible/roles/openshift_examples/files/examples/v1.2/infrastructure-templates/origin/logging-deployer.yaml

### Make sure to delete any old secret, and use a new empty secret.  
### This secret will be used by kibana to talk to ES servers, and scrape the logs.  very important that its in sync.
sudo oc delete secret logging-deployer || echo "couldn't delete secret!!!!!!" ; sleep 5
sudo oc secrets new logging-deployer nothing=/dev/null
 
## Now create svc/roles

oc create -f - <<API
apiVersion: v1
kind: ServiceAccount
metadata:
  name: logging-deployer
secrets:
- name: logging-deployer
API

oc policy add-role-to-user edit --serviceaccount logging-deployer

oadm policy add-scc-to-user privileged system:serviceaccount:logging:aggregated-logging-fluentd

oadm policy add-cluster-role-to-user cluster-reader system:serviceaccount:logging:aggregated-logging-fluentd

### Finally start deploying the logging components.

oc process logging-deployer-template -v KIBANA_HOSTNAME=kibana.example.com,ES_CLUSTER_SIZE=1,PUBLIC_MASTER_URL=https://localhost:8443,IMAGE_VERSION=3.1.0,IMAGE_PREFIX=registry.access.redhat.com/openshift3/ | oc create -f -


# edit this template to add 'hostPort: 1234' under any of the ports sections.
# This forces ES spreading.
# for example:
#           ports:
#           - containerPort: 9200
#             hostPort: 1234
#             name: restapi
#           - containerPort: 9300 
#            purpose: to prevent more than one per node
# 
# template "logging-es-template" edited
echo "now, edit the port for spreading, containerPort: 9200 , hostPort: 1234.... sleeping first..."
sleep 10

until oc get pods | grep -q Completed
do
	oc get pods
	echo "waiting for completion..."
	sleep 1
done
oc edit template logging-es-template 

oc process logging-support-template | oc create -f -

### You should see some ELK pods by now 

oc get pods --all-namespaces

echo "Not gauranteed that everything will pass w/ exit code 0 below, so unsetting -e"
echo "For example: Some creates may fail but probably its nothing to worry about (yet) :)"
unset -e
 
### Now deploy the rest of the infra

oc process logging-support-template | oc create -f -

oc get dc --selector logging-infra=elasticsearch

# Now scale up the ES instances...
oc process logging-es-template | oc create -f -

oc get pods --all-namespaces

### Finally, create FluentD replicas...

oc scale dc/logging-fluentd --replicas=10

### You should see something like this...

```
default     docker-registry-1-35gi9       1/1       Running     0          11d
default     redorouter-3-w964o            1/1       Running     0          11d
logging     logging-deployer-4e0l0        0/1       Completed   0          23m
logging     logging-es-2e42h1qh-1-jl5k7   1/1       Running     0          13m
logging     logging-es-7sxulsdb-1-3dxoo   1/1       Running     0          4m
logging     logging-es-ddwewixj-1-1qoid   1/1       Running     0          4m
logging     logging-es-uyod2c2e-1-0xsq9   1/1       Running     0          6m
logging     logging-fluentd-1-2xmmt       1/1       Running     0          3m
logging     logging-fluentd-1-4rsfy       1/1       Running     0          3m
logging     logging-fluentd-1-9u13m       1/1       Running     0          3m
logging     logging-fluentd-1-cfn06       1/1       Running     0          3m
logging     logging-fluentd-1-kwhnq       1/1       Running     0          3m
logging     logging-fluentd-1-m0hzm       1/1       Running     0          3m
logging     logging-fluentd-1-qe2qb       1/1       Running     0          3m
logging     logging-fluentd-1-vy0t3       1/1       Running     0          3m
logging     logging-fluentd-1-zcwu6       1/1       Running     0          3m
logging     logging-fluentd-1-zrsk7       1/1       Running     0          3m
logging     logging-kibana-1-8pip6        2/2       Running     0          13m
```

### SMOKE TEST of kibana logs w/o need for a router
export LOGGING_ES=logging-es 
# or LOGGING_ES=logging-es-ops
oc exec logging-kibana-1-8pip6 -- curl --connect-timeout 2 -s -k --cert /etc/kibana/keys/cert --key /etc/kibana/keys/key https://$LOGGING_ES:9200/.operations*/_search
