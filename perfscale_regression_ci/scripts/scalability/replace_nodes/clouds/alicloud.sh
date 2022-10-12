source ./common.sh

export OPENSHIFT_INFRA_NODE_VOLUME_SIZE=100
export OPENSHIFT_WORKER_NODE_INSTANCE_TYPE=ecs.g6.2xlarge
export OPENSHIFT_WORKER_NODE_VOLUME_SIZE=500

export WORKER_MACHINESET_IMAGE=$(oc get machineset ${WORKER_NODE_MACHINESET} -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.imageId}')
export CLUSTER_REGION=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index .items 0).spec.template.spec.providerSpec.value.regionId}}')
