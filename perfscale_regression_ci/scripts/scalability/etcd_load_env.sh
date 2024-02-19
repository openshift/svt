# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../kubeburner-object-templates/loaded-projects-config.yml"}
# ENVs to overwrite the kube-burner configuration file
export NAME=${NAME:-"loaded-projects"}
export NAMESPACE=${NAMESPACE:-"loaded-projects"}
export JOB_ITERATION=${JOB_ITERATION:-10}
export QPS=${QPS:-50}
export BURST=${BURST:-50}
export WAIT_FOR=${WAIT_FOR:-["Pod","BuildConfig"]}
export DEPLOYMENT_REPLICAS=2
export IMAGES_STREAM_REPLICAS=10
export BUILDS_REPLICAS=6
export SECRETS_REPLICAS=10
export ROUTES_REPLICAS=5
export CM_REPLICAS=10
