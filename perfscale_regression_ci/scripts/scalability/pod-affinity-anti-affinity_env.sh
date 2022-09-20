# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../kubeburner-object-templates/pod-affinity-anti-affinity-config.yml"}
# ENVs to overwrite the kube-burner configuration file
export POD_AFFINTIY_NAME=${POD_AFFINTIY_NAME:-"pod-affinity-s1-0"}
export POD_AFFINTIY_NAMESPACE=${POD_AFFINTIY_NAMESPACE:-"pod-affinity-s1-0"}
export POD_ANTI_AFFINTIY_NAME=${POD_ANTI_AFFINTIY_NAME:-"pod-anti-affinity-s1-0"}
export POD_ANTI_AFFINTIY_NAMESPACE=${POD_ANTI_AFFINTIY_NAMESPACE:-"pod-anti-affinity-s1-0"}
export POD_ANTI_AFFINITY_JOB_ITERATION=${POD_ANTI_AFFINITY_JOB_ITERATION:-190}
export POD_AFFINITY_JOB_ITERATION=${POD_AFFINITY_JOB_ITERATION:-190}
# Other ENV needed by the test case script