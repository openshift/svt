# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../kubeburner-object-templates/statefulset-config.yml"}
# ENVs to overwrite the kube-burner configuration file
export NAME=${NAME:-"statefulset"}
export NAMESPACE=${NAMESPACE:-"statefulset"}
export JOB_ITERATION=${JOB_ITERATION:-1}
export QPS=${QPS:-50}
export BURST=${BURST:-50}
export WAIT_FOR=${WAIT_FOR:-[Pod]}
export GEN_CSV=false
export COMPARISON_CONFIG="clusterVersion.json"
