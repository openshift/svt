# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../kubeburner-object-templates/node-affinity-anti-affinity-config.yml"}
# ENVs to overwrite the kube-burner configuration file
export AFFINTIY_NAME=${AFFINTIY_NAME:-"node-affinity-0"}
export AFFINTIY_NAMESPACE=${AFFINTIY_NAMESPACE:-"node-affinity-0"}
export ANTI_AFFINTIY_NAME=${ANTI_AFFINTIY_NAME:-"node-anti-affinity-0"}
export ANTI_AFFINTIY_NAMESPACE=${ANTI_AFFINTIY_NAMESPACE:-"node-anti-affinity-0"}
export ANTI_AFFINITY_JOB_ITERATION=${ANTI_AFFINITY_JOB_ITERATION:-130}
export AFFINITY_JOB_ITERATION=${AFFINITY_JOB_ITERATION:-200}
#export QPS=${QPS:-50}
#export BURST=${BURST:-50}
export SERVICE_TYPE=${SERVICE_TYPE:-"ClusterIP"}
# Other ENV needed by the test case script