# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../kubeburner-object-templates/node-affinity-anti-affinity-config.yaml"}
# ENVs to overwrite the kube-burner configuration file
export AFFINTIY_NAME=${AFFINTIY_NAME:-"node-affinity-0"}
export AFFINTIY_NAMESPACE=${AFFINTIY_NAMESPACE:-"node-affinity-0"}
export ANTI_AFFINTIY_NAME=${ANTI_AFFINTIY_NAME:-"node-anti-affinity-0"}
export ANTI_AFFINTIY_NAMESPACE=${ANTI_AFFINTIY_NAMESPACE:-"node-anti-affinity-0"}
export ANTI_AFFINITY_JOB_ITERATION=${ANTI_AFFINITY_JOB_ITERATION:-190}
export AFFINITY_JOB_ITERATION=${AFFINITY_JOB_ITERATION:-190}
# Other ENV needed by the test case script