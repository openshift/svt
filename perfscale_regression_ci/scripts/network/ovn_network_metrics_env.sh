# WORKLOAD_TEMPLATE for custom workload of kube-burner
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKLOAD_TEMPLATE=${WORKLOAD_TEMPLATE:-"${DIR}/../../kubeburner-object-templates/ovn-network-metrics-config.yaml"}
# ENVs to overwrite the kube-burner configuration file
export NAME=${NAME:-"ovn-network-metrics"}
export NAMESPACE=${NAMESPACE:-"ovn-network-metrics"}
export JOB_ITERATION=${JOB_ITERATION:-15}
export QPS=${QPS:-50}
export BURST=${BURST:-50}
export POD_REPLICAS=${POD_REPLICAS:=500}
# Other ENV needed by the test case script
export NETWORK_POLICY=${NETWORK_POLICY:-"${DIR}/../../content/ovn_metrics_network_policy.yaml"}