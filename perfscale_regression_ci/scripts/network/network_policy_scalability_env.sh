# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../kubeburner-object-templates/scaling-network-policy-config.yaml"}
# ENVs to overwrite the kube-burner configuration file
export JOB_ITERATION=${JOB_ITERATION:=1}
export WAIT_FOR=["Deployment"]
export POD_REPLICAS=${POD_REPLICAS:=2000}
# Other ENV needed by the test case script
export NETWORK_POLICY=${NETWORK_POLICY:-"${DIR}/../../content/scaling_network_policy.yaml"}