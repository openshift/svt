#/!/bin/bash
################################################
## Auth=prubenda@redhat.com
## Desription: Script for creating objects and validating the descheduler operator 
## moves pods using pvc's to new nodes
## Be sure to follow steps in README.md to install descheduler and correct profiles for this test
## Expected profiles:
##    - AffinityAndTaints
## Polarion test case: OCP-66655
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-66655
## Cluster config: 3 master (m5.xlarge or equivalent) with 3 workers
## kube-burner config: perfscale_regerssion_ci/kubeburner-object-templates/descheduler-evict-pvc.yml
## optional PARAMETERS: number of JOB_ITERATION
################################################ 

source ../../common.sh
source common_func.sh
source affinity_taint_env.sh
source ../../../utils/run_workload.sh
source ../../custom_workload_env.sh

./operator/create_operator.sh
validate_descheduler_installation "AffinityAndTaints"

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

# Validate RemovePodsViolatingNodeAffinity
# Only create ~200 pods because they'll all be on one node
echo "======Use kube-burner to load the cluster with test objects======"
run_workload

# taint the node that wasn't cordoned 
oc adm taint node $first_worker dedicated=special-user:NoSchedule

uncordon_all_nodes

# set to sleep for time for decheduler to run
wait_for_descheduler_to_run

get_descheduler_evicted
worker_nme=$(get_node_name $first_worker)

pass_or_fail=0
echo $worker_nme
pod_count=$(count_running_pods $NAMESPACE-$((JOB_ITERATION-1)) $worker_nme dedicated-nodes-test)
echo "$pod_count dedicated-nodes-test pods on $worker_nme"
if [[ $pod_count -eq 0 ]]; then
  echo "PASS"
  (( ++pass_or_fail ))
else
  echo "FAIL, expected less than 110 pods on worker node"
fi

# Untaint first node
oc adm taint node $first_worker dedicated=special-user:NoSchedule-
