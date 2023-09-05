# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export JOBNAME="mem-util-desched"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../../kubeburner-object-templates/pause-config.yaml"}
# ENVs to overwrite the kube-burner configuration file
export WAIT_FOR=[]
export POD_WAIT=true
export NAME=${NAME:-"mem-util-desched"}
export NAMESPACE=${NAMESPACE:-"mem-util-desched"}
export JOB_ITERATION=${JOB_ITERATION:=19}
export TEST_JOB_ITERATIONS=${JOB_ITERATION}

export QPS=${QPS:-50}
export BURST=${BURST:-50}
export SERVICE_TYPE=${SERVICE_TYPE:-"ClusterIP"}
export POD_WAIT=${POD_WAIT:-false}
export MAX_WAIT_TIMEOUT=${MAX_WAIT_TIMEOUT:-3h}
export JOB_TIMEOUT=${JOB_TIMEOUT:-3h}
export VERIFY_OBJECTS=${VERIFY_OBJECTS:-true}
# Other ENV needed by the test case script
export NETWORK_POLICY=${NETWORK_POLICY:-"${DIR}/../../content/allow_default_network_policy.yaml"}