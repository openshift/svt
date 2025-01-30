# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../../kubeburner-object-templates/descheduler-evict-pvc.yml"}
# ENVs to overwrite the kube-burner configuration file
export NAME=${NAME:-"evict-pvc-desched"}
export NAMESPACE=${NAMESPACE:-"evict-pvc-desched"}
export WAIT_FOR=["PersistentVolumeClaim","ReplicationController"]
export JOB_ITERATION=${JOB_ITERATION:-1}
export PROFILE1="TopologyAndDuplicates"
export PROFILE2="EvictPodsWithPVC"