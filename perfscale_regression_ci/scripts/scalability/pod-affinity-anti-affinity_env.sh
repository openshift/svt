# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../kubeburner-object-templates/pod-affinity-anti-affinity-config.yaml"}
# ENVs to overwrite the kube-burner configuration file
export S1_PROJ_NAME=${S1_PROJ_NAME:-"s1-proj"}
export S1_PROJ_NAMESPACE=${S1_PROJ_NAMESPACE:-"s1-proj"}
export S1_PROJ_JOB_ITERATION=${S1_PROJ_JOB_ITERATION:-1}
export POD_AFFINTIY_NAME=${POD_AFFINTIY_NAME:-"pod-affinity-s1-0"}
export POD_AFFINTIY_NAMESPACE=${POD_AFFINTIY_NAMESPACE:-"pod-affinity-s1-0"}
export POD_AFFINITY_JOB_ITERATION=${POD_AFFINITY_JOB_ITERATION:-190}
export POD_ANTI_AFFINTIY_NAME=${POD_ANTI_AFFINTIY_NAME:-"pod-anti-affinity-s1-0"}
export POD_ANTI_AFFINTIY_NAMESPACE=${POD_ANTI_AFFINTIY_NAMESPACE:-"pod-anti-affinity-s1-0"}
export POD_ANTI_AFFINITY_JOB_ITERATION=${POD_ANTI_AFFINITY_JOB_ITERATION:-190}
# Other ENV needed by the test case script