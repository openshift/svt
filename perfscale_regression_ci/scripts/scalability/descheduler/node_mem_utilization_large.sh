#/!/bin/bash
################################################
## Auth=prubenda@redhat.com lhorsley@redhat.com
## Desription: This testcase tests descheduling pods in a deployment at scale	
## Polarion test case: OCP-67198 - Descheduler - Validate Mem and CPU Usage using LifecycleAndUtilization profile	
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-67198
## Cluster config: Cluster needed in AWS EC2 (at least m6i.large, 3 master/etcd, 8 worker/compute nodes (all in same machineset))
################################################ 

export JOB_ITERATION=110

source ../../common.sh
source common_func.sh
source common_func.sh
source node_mem_utilization_env.sh
source ../../../utils/run_workload.sh
source ../../custom_workload_env.sh
source ../../../kubeburner-object-templates/openshift-template/cakephp/cakephp-mysql-persistent.env.sh

i=0

pass_or_fail=0

validate_descheduler_installation "LifecycleAndUtilization"

echo "Prepare worker nodes"
worker_nodes=$(get_worker_nodes)

COUNTER=0
iterations=3
echo "counter $COUNTER"
cordon_num_nodes 4

echo "======Use kube-burner to load the cluster with test objects - $NAMESPACE======"
run_workload

wait_for_obj_creation build pods

uncordon_all_nodes

echo "Wait for descheduler to run"
wait_for_descheduler_to_run

echo "Get descheduler evicted, want to be more than 100 "
get_descheduler_evicted