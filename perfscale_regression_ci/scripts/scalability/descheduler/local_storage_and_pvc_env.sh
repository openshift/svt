# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../../kubeburner-object-templates/descheduler-local-storage.yml"}
# ENVs to overwrite the kube-burner configuration file
export NAME=${NAME:-"local-storage-desched"}
export NAMESPACE=${NAMESPACE:-"local-storage-desched"}
export WAIT_FOR=["PersistentVolumeClaim","ReplicationController"]
export JOB_ITERATION=${JOB_ITERATION:=1}
export PROFILE1="TopologyAndDuplicates"
export PROFILE2="EvictPodsWithLocalStorage"