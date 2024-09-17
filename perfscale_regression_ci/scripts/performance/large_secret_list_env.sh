# ENVs to overwrite the kube-burner configuration file
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE="${DIR}/../../kubeburner-object-templates/secret-projects-config.yml"
export NAME=${NAME:-"large-secrets"}
export NAMESPACE=${NAMESPACE:-"large-secrets"}
export JOB_ITERATION=${PARAMETERS:=100}
export SECRET_REPLICAS=${SECRET_REPLICAS:=20}
