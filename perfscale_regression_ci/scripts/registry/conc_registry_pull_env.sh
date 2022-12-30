# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../kubeburner-object-templates/openshift-template/cakephp/cakephp-mysql-persistent.yaml"}
# ENVs to overwrite the kube-burner configuration file
export JOBNAME=${JOBNAME:-"conc-registry-pull"}
export NAMESPACE=${NAMESPACE:-"conc-registry-pull"}
export TEST_JOB_ITERATIONS=${TEST_JOB_ITERATIONS:-5000}
export QPS=${QPS:-20}
export BURST=${BURST:-20}
export SERVICE_TYPE=${SERVICE_TYPE:-"ClusterIP"}
export POD_WAIT=${POD_WAIT:-false}
export MAX_WAIT_TIMEOUT=${MAX_WAIT_TIMEOUT:-5h}
export JOB_TIMEOUT=${JOB_TIMEOUT:-5h}
export INDEXING=true
export METADATA_COLLECTION=true
export TOUCHSTONE_NAMESPACE="openshift-image-registry"
export GEN_CSV=true
# Other ENV needed by the test case script
