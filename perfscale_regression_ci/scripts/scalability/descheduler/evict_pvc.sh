#/!/bin/bash
################################################
## Auth=prubenda@redhat.com qili@redhat.com
## Desription: Script for creating objects and validating the descheduler operator 
## moves pods using pvc's to new nodes
## Be sure to follow steps in README.md to install descheduler and correct profiles for this test
## Expected profiles:
##    - TopologyAndDuplicates
##    - EvictPodsWithPVC
## Polarion test case: OCP-44285
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-44285
## Cluster config: 3 master (m5.xlarge or equivalent) with 3 workers
## kube-burner config: perfscale_regerssion_ci/kubeburner-object-templates/descheduler-evict-pvc.yml
## optional PARAMETERS: number of JOB_ITERATION
################################################ 

source ../../common.sh
source common_func.sh
source evict_pvc_env.sh
source ../../../utils/run_workload.sh
source ../../custom_workload_env.sh

validate_descheduler_installation "TopologyAndDuplicates,EvictPodsWithPVC"

node=""
worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker= -o name)
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

export STORAGE_CLASS=$(get_storageclass)

echo "======Use kube-burner to load the cluster with test objects======"
run_workload

uncordon_all_nodes

# set to sleep for time for decheduler to run
wait_for_descheduler_to_run

get_descheduler_evicted
worker_nme=$(get_node_name $first_worker)

pass_or_fail=0
echo $worker_nme
pod_count=$(count_running_pods $NAMESPACE-$((JOB_ITERATION-1)) $worker_nme rcexpv)
echo "$pod_count rcexpv pods on $worker_nme"
if [[ $pod_count -lt 110 ]]; then
  echo "PASS"
  (( ++pass_or_fail ))
else
  echo "FAIL, expected less than 110 pods on worker node"
fi


lc_pod_count=$(count_running_pods $NAMESPACE-$((JOB_ITERATION-1)) $worker_nme rcexlc)
echo "$lc_pod_count rcexlc pods on $worker_nme"

#update for current test case

if [[ $lc_pod_count -ge 110 ]]; then
  echo "PASS"
  (( ++pass_or_fail ))
else
  echo "FAIL, expected there to still be 110 pods on worker node"
fi

echo "======Final test result======"
if [[ ${pass_or_fail} == 2 ]]; then
  echo -e "\nOverall Descheduler - Validate default EvictPodsWithLocalStorage & EvictPodsWithPVC profiles Testcase result:  PASS"
  echo "======Clean up test environment======"
  # # delete projects:
  # ######### Clean up: delete projects and wait until all projects and pods are gone
  echo "Deleting test objects"
  delete_project_by_label kube-burner-job=$NAME

  exit 0
else
  echo -e "\nOverall Descheduler - Validate default EvictPodsWithLocalStorage & EvictPodsWithPVC profiles Testcase result:  FAIL"
  echo "Please debug. When debugging is complete, delete all projects using 'oc delete project -l kube-burner-job=$NAME'"
  exit 1
fi