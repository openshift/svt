#/!/bin/bash
################################################
## Auth=prubenda@redhat.com lhorsley@redhat.com
## Desription: This testcase tests descheduling pods in a deployment at scale	
## Polarion test case: OCP-44241 - Descheduler - Validate Descheduling Pods in a Deployment at scale		
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-44241
## Cluster config: Cluster needed in AWS EC2 (at least m6i.large, 3 master/etcd, 3 worker/compute nodes)
################################################ 

source ../../common.sh
source common_func.sh
source duplicates_profile_env.sh
source ../../../utils/run_workload.sh
source ../../custom_workload_env.sh

project_name="perf-test-pod-descheduler"
project_label="test=$project_name"
object_type="pods"
i=0
last_worker=""
first_worker=""
middle_worker=""
pass_or_fail=0
scale_num=190

./operator/create_operator.sh
validate_descheduler_installation "TopologyAndDuplicates"

echo "Create and label new project"
prepare_project $project_name $project_label


echo "Prepare worker nodes"
worker_nodes=$(get_worker_nodes)

for worker in ${worker_nodes}; do
  if [[ $i -eq 0 ]]; then
    first_worker=$worker
  elif [[ $i -eq 1 ]]; then
    oc adm cordon $worker
    middle_worker=$worker
  elif [[ $i -eq 2 ]]; then
    oc adm cordon $worker
    last_worker=$worker
  fi
  i=$((i + 1))
done

counter=0
project_name_list=('duplicates-desched-first' 'duplicates-desched-sec' 'duplicates-desched-third')
for project_name in "${project_name_list[@]}"; do

  if [[ $counter -eq 1 ]]; then
    oc adm uncordon $middle_worker
    oc adm cordon $first_worker
  elif [[ $counter -eq 2 ]]; then
    oc adm uncordon $last_worker
    oc adm cordon $middle_worker
  fi
  export NAME=$project_name
  export NAMESPACE=$project_name
  echo "======Use kube-burner to load the cluster with test objects - $project_name======"
  run_workload
  counter=$((counter + 1))
done

uncordon_all_nodes

echo "Wait for descheduler to run"
wait_for_descheduler_to_run

echo "Get descheduler evicted"
get_descheduler_evicted

deployment="hello-1"
for project_name in "${project_name_list[@]}"; do
  for worker in ${worker_nodes}; do
    pod_count=$(count_running_pods ${project_name}-1 $(get_node_name ${worker}) ${deployment})
    echo "$pod_count $deployment $object_type on $worker "
    if [[ $pod_count -ne ${POD_REPLICAS} ]]; then
      pass_or_fail=$((pass_or_fail + 1))
    fi
  done
  echo "\n"
done

echo "======Final test result======"
if [[ ${pass_or_fail} -ge 9 ]]; then
  echo -e "\nDescheduler - Validate Descheduling Pods in a Deployment at scale Testcase result:  PASS"
  echo "======Clean up test environment======"
  echo "Deleting test objects"
 # delete_project_by_label kube-burner-job

  exit 0
else
  echo -e "\nDescheduler - Validate Descheduling Pods in a Deployment at scale Testcase result:  FAIL"
  echo "Please debug. When debugging is complete, delete all projects using 'oc delete project kube-burner-job' "
  exit 1
fi