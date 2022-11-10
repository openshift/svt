# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../../kubeburner-object-templates/descheduler-duplicates.yml"}
# ENVs to overwrite the kube-burner configuration file
export WAIT_FOR=["Deployment"]
export JOB_ITERATION=${JOB_ITERATION:=1}
export POD_REPLICAS=${POD_REPLICAS:=190}