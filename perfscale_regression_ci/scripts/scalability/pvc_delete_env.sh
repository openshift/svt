# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../kubeburner-object-templates/pvc-config.yaml"}
# ENVs to overwrite the kube-burner configuration file
export NAME=${NAME:-"pvc-delete"}
export NAMESPACE=${NAMESPACE:-"pvc-delete"}
export JOB_ITERATION=${JOB_ITERATION:-1}
export QPS=${QPS:-50}
export BURST=${BURST:-50}
export WAIT_FOR=${WAIT_FOR:-["PersistentVolumeClaim"]}
export METRICS_PROFILE=""
export COMPARISON_CONFIG=""

