#/!/bin/bash
################################################
## Auth=prubenda@redhat.com
## Desription: Script for creating statefulsets per node and checking the status of created pods
###############################################

source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source ../common.sh
source statefulset_perf_env.sh
set +x

export JOB_ITERATION=1
export OBJ_REPLICAS=75

export STORAGE_CLASS=$(get_storageclass)
echo "job iterations $JOB_ITERATION $OBJ_REPLICAS"
echo "======Use kube-burner to load the cluster with test objects======"
run_workload

oc describe nodes -l 'node-role.kubernetes.io/worker='

running_pods=$(oc get pods -A | grep $NAME | grep Running -c)
if [ $running_pods == $OBJ_REPLICAS ]; then
  echo -e "Actual $running_pods pods were sucessfully deployed. First statefulset passed!"
  (( ++pass_or_fail ))
else
  echo -e "Actual $running_pods pods deployed does NOT match expected $OBJ_REPLICAS pods for test.  First statefulset test failed !"
fi

echo "Deleting test objects -1 "
delete_project_by_label kube-burner-job=$NAME

export JOB_ITERATION=75
export OBJ_REPLICAS=1
echo "job iterations $JOB_ITERATION $OBJ_REPLICAS"
echo "======Use kube-burner to load the cluster with test objects======"
run_workload

oc describe nodes -l 'node-role.kubernetes.io/worker='

running_pods=$(oc get pods -A | grep $NAME | grep Running -c)
if [ $running_pods == $JOB_ITERATION ]; then
  echo -e "Actual $running_pods pods were sucessfully deployed. Second statefulset passed!"
  (( ++pass_or_fail ))
else
  echo -e "Actual $running_pods pods deployed does NOT match expected $JOB_ITERATION pods for test.  Second statefulset test failed !"
fi

echo "Deleting test objects - 2nd Set"
delete_project_by_label kube-burner-job=$NAME

echo "======Final test result======"
if [[ ${pass_or_fail} == 2 ]]; then
  echo -e "\nOverall Statefulset Testcase result:  PASS"
  exit 0
else
  echo -e "\nOverall Statefulset Testcase result:  FAIL"
  echo "Please debug. When debugging is complete, delete all projects using 'oc delete project -l kube-burner-job=$NAME'"
  exit 1
fi