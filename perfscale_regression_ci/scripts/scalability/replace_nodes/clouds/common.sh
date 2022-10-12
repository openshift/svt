export CLUSTER_NAME=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index (index .items 0).metadata.labels "machine.openshift.io/cluster-api-cluster" )}}')
echo $CLUSTER_NAME

first_worker_node=$(oc get nodes -l 'node-role.kubernetes.io/worker=' --no-headers -o name | head -n 1)
export WORKER_NODE_MACHINESET=$(oc get machinesets --no-headers -n openshift-machine-api | awk {'print $1'} | awk 'NR==1{print $1}')

export NETWORK_NAME="$CLUSTER_NAME-network"
export SUBNET_NETWORK_NAME="$CLUSTER_NAME-worker-subnet"

if [[ $(oc get machineset -n openshift-machine-api $(oc get machinesets -A  -o custom-columns=:.metadata.name | shuf -n 1) -o=jsonpath='{.metadata.annotations}' | grep -c "machine.openshift.io") -ge 1 ]]; then
    export MACHINESET_METADATA_LABEL_PREFIX=machine.openshift.io
else
    export MACHINESET_METADATA_LABEL_PREFIX=sigs.k8s.io
fi
