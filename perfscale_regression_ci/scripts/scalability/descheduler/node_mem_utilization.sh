#/!/bin/bash
################################################
## Auth=prubenda@redhat.com lhorsley@redhat.com
## Desription: This testcase tests descheduling pods in a deployment at scale	
## Polarion test case: OCP-44291 - Descheduler - Validate Validate Node Utilization using LifecycleAndUtilization profile
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-44291
## Cluster config: Cluster needed in AWS EC2 (at least m6i.large, 3 master/etcd, 3 worker/compute nodes(all in same machineset))
################################################ 

source ../../common.sh
source common_func.sh
source node_mem_utilization_env.sh
source ../../../utils/run_workload.sh
source ../../custom_workload_env.sh

i=0

pass_or_fail=0

validate_descheduler_installation "LifecycleAndUtilization"

echo "Prepare worker nodes"
worker_nodes=$(get_worker_nodes)

i=0
last_worker=""
first_worker=""
for worker in ${worker_nodes}; do
  if [[ $i -eq 0 ]]; then
    first_worker=$worker
  else
    oc adm cordon $worker
    last_worker=$worker
  fi
  i=$((i + 1))
done

env

echo "======Use kube-burner to load the cluster with test objects - $NAMESPACE======"
run_workload

uncordon_all_nodes

echo "Wait for descheduler to run"
wait_for_descheduler_to_run

echo "Get descheduler evicted"
get_descheduler_evicted

first_node_count=$(count_running_pods_all $first_worker $NAMESPACE)
if [[ $first_node_count -ge $JOB_ITERATION ]]; then
  echo "FAIL"
else
  echo "PASS"
  (( ++pass_or_fail ))
fi

echo "======Final test result======"
if [[ ${pass_or_fail} -eq 1 ]]; then
  echo -e "\nDescheduler - Validate Descheduling Pods with High Node Utilization result:  PASS"
  echo "======Clean up test environment======"
  echo "Deleting test objects"
 # delete_project_by_label kube-burner-job

  exit 0
else
  echo -e "\nDescheduler - Validate Descheduling Pods with High Node Utilization Testcase result:  FAIL"
  echo "Please debug. When debugging is complete, delete all projects using 'oc delete project kube-burner-job' "
  exit 1
fi