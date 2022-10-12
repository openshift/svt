source ./common.sh

export OPENSHIFT_INFRA_NODE_VOLUME_SIZE=128
export OPENSHIFT_INFRA_NODE_VOLUME_TYPE=gp2
export OPENSHIFT_WORKER_NODE_INSTANCE_TYPE=m5.2xlarge

export AWS_REGION=$(oc get ${first_worker_node} -o=jsonpath='{.metadata.labels}' |  jq '."topology.kubernetes.io/region"' | sed 's/"//g' )
export AMI_ID=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index .items 0).spec.template.spec.providerSpec.value.ami.id}}')

export WORKER_MACHINESET_IMAGE=$(oc get machineset ${WORKER_NODE_MACHINESET} -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.disks[0].image}')
export CLUSTER_REGION=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index .items 0).spec.template.spec.providerSpec.value.placement.region}}')
