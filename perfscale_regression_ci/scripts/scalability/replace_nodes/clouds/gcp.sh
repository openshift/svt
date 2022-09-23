source ./common.sh

export OPENSHIFT_INFRA_NODE_VOLUME_SIZE=128
export OPENSHIFT_INFRA_NODE_VOLUME_TYPE=pd-ssd
export OPENSHIFT_WORKER_NODE_INSTANCE_TYPE=n1-standard-8

export GCP_PROJECT=openshift-qe
export GCP_REGION=$(oc get ${first_worker_node} -o=jsonpath='{.metadata.labels}' |  jq '."topology.kubernetes.io/region"' | sed 's/"//g' )
export GCP_SERVICE_ACCOUNT_EMAIL=openshift-qe.iam.gserviceaccount.com

export WORKER_MACHINESET_IMAGE=$(oc get machineset ${WORKER_NODE_MACHINESET} -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.disks[0].image}')
