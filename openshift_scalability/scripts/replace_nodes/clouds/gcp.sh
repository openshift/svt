export CLUSTER_NAME=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index (index .items 0).metadata.labels "machine.openshift.io/cluster-api-cluster" )}}')
echo $CLUSTER_NAME
export OPENSHIFT_INFRA_NODE_VOLUME_SIZE=128
export OPENSHIFT_INFRA_NODE_VOLUME_TYPE=pd-ssd
export OPENSHIFT_WORKER_NODE_INSTANCE_TYPE=n1-standard-8
export GCP_PROJECT=openshift-qe
first_worker_node=$(oc get nodes -l 'node-role.kubernetes.io/worker=' --no-headers -o name | head -n 1)
export GCP_REGION=$(oc get ${first_worker_node} -o=jsonpath='{.metadata.labels}' |  jq '."topology.kubernetes.io/region"' | sed 's/"//g' )
export WORKER_NODE_MACHINESET=$(oc get machinesets --no-headers -n openshift-machine-api | awk {'print $1'} | awk 'NR==1{print $1}')
export WORKER_MACHINESET_IMAGE=$(oc get machineset ${WORKER_NODE_MACHINESET} -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.disks[0].image}')

export NETWORK_NAME="$CLUSTER_NAME-network"

echo $NETWORK_NAME
export SUBNET_NETWORK_NAME="$CLUSTER_NAME-worker-subnet"
export GCP_SERVICE_ACCOUNT_EMAIL=openshift-qe.iam.gserviceaccount.com

if [[ $(oc get machineset -n openshift-machine-api $(oc get machinesets -A  -o custom-columns=:.metadata.name | shuf -n 1) -o=jsonpath='{.metadata.annotations}' | grep -c "machine.openshift.io") -ge 1 ]]; then
    export MACHINESET_METADATA_LABEL_PREFIX=machine.openshift.io
else
    export MACHINESET_METADATA_LABEL_PREFIX=sigs.k8s.io
fi
