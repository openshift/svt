#/!/bin/bash
################################################
## Auth=prubenda@redhat.com lhorsley@redhat.com
## Desription: This testcase tests Node Affinity and anti-affinity as we approach to node capacity	
## Polarion test case: OCP-18082 - NextGen Pod scheduler at capacity with Node Affinity and Anti-Affinity rules	
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-18082
## Cluster config: Cluster needed in AWS EC2 (m5.xlarge, 3 master/etcd, 3 worker/compute nodes)
## kube-burner config: perfscale_regerssion_ci/kubeburner-object-templates/node-affinity-anti-affinity-config.yml
################################################ 


source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source ../common.sh
source node-affinity-anti-affinity_env.sh

function show_node_labels() {
  oc get node --show-labels
  oc get node -l cpu=4
  oc get node -l cpu=6
  oc get node -l beta.kubernetes.io/arch=intel
}


export ANTI_AFFINITY_JOB_ITERATION=${ANTI_AFFINITY_JOB_ITERATION:-190}
export AFFINITY_JOB_ITERATION=${AFFINITY_JOB_ITERATION:-190}

# Output some general information about the test environment
date
uname -a
oc get clusterversion
oc version
oc get node --show-labels
oc describe node | grep Runtime


echo "======Setup/Configuration: label nodes for Affinity and anti-affinity scheduling======"

compute_nodes=$(oc get nodes -l 'node-role.kubernetes.io/worker=' | awk '{print $1}' | grep -v NAME | xargs)

echo -e "\nWorker  nodes are: $compute_nodes"

declare -a node_array
counter=1


for n in ${compute_nodes}; do
  node_array[${counter}]=${n}
  counter=$((counter+1))
done

# output node array elements
for i in {1..2}; do
  echo "Array element node_array index $i has value : ${node_array[${i}]}"
done


# The following code removes node labels created by the test run and then show the labels have been removed.
# Uncomment the code when running  this test repeatedly on the same cluster (during debugging) to ensure the 
# node labels are removed. Otherwise, the test will fail/end prematurely.
#   echo -e "\nRemoving the node labels"
# initial_node_label="beta.kubernetes.io/arch=amd64"
# oc label nodes ${node_array[1]} cpu-
# oc label nodes ${node_array[2]} cpu-
# oc label nodes ${node_array[1]} --overwrite ${initial_node_label}


echo -e "\nLabeling node ${node_array[1]} with label 'cpu=4'"
oc label nodes ${node_array[1]} cpu=4

echo -e "\nLabeling node ${node_array[2]} with label 'cpu=6'"
oc label nodes ${node_array[2]} cpu=6

echo -e "\nLabeling node ${node_array[1]} with label 'beta.kubernetes.io/arch=intel'"
oc label nodes ${node_array[1]} --overwrite beta.kubernetes.io/arch=intel

show_node_labels

sleep 5


echo "======Use kube-burner to load the cluster with test objects======"
run_workload

oc get nodes -l 'node-role.kubernetes.io/worker='
oc describe nodes -l 'node-role.kubernetes.io/worker='

initial_node_label="beta.kubernetes.io/arch=amd64"


echo "======Checking the pods for errors======"

check_no_error_pods $AFFINTIY_NAMESPACE

check_no_error_pods $ANTI_AFFINTIY_NAMESPACE


echo "======Counting Pods in each namespace======"
node_affinity_pods_expected=$AFFINITY_JOB_ITERATION
node_anti_affinity_pods_expected=$ANTI_AFFINITY_JOB_ITERATION

echo "nodes ${node_array}"

node_affinity_pods_actual=$(oc get pods -n node-affinity-0 -o wide | grep "node-affinity" | grep ${node_array[2]} | grep Running | wc -l | xargs )

node_anti_affinity_pods_actual=$(oc get pods -n node-anti-affinity-0 -o wide | grep "hello-pod-anti-affinity" | grep -v ${node_array[2]} | grep Running | wc -l | xargs)


echo "======Compare the expected and actual number of pods for each namespace. Get the PASS/FAIL result for each namespace======"
pass_or_fail=0

echo "node_affinity_pods_expected $node_affinity_pods_expected"

if [ $node_affinity_pods_expected == $node_affinity_pods_actual ]; then
  echo -e "Actual $node_affinity_pods_actual pods were sucessfully deployed. Node affinity test passed!"
  (( ++pass_or_fail ))
else
  echo -e "Actual $node_affinity_pods_actual pods deployed does NOT match expected $node_affinity_pods_expected pods for node affinity test.  Node affinity test failed !"
fi


echo "node_anti_affinity_pods_expected $node_anti_affinity_pods_expected"

if [ $node_anti_affinity_pods_expected == $node_anti_affinity_pods_actual ]; then
  echo -e "Actual $node_anti_affinity_pods_actual pods were sucessfully deployed.  Node Anti-affinity test passed!"
  (( ++pass_or_fail ))
else
  echo -e "Actual $node_anti_affinity_pods_actual pods deployed does NOT match expected $node_anti_affinity_pods_expected pods for node Anti-affinity test. Node Anti-affinity test failed !"
fi


echo "======Final test result======"
if [[ ${pass_or_fail} == 2 ]]; then
  echo -e "\nOverall Node Affinity and Anti-affinity Testcase result:  PASS"
  echo "======Clean up test environment======"
  # # delete projects:
  # ######### Clean up: delete projects and wait until all projects and pods are gone
  echo "Deleting test objects"
  delete_project_by_label kube-burner-job=$AFFINTIY_NAME
  delete_project_by_label kube-burner-job=$ANTI_AFFINTIY_NAME

  #sleep 30

  ## remove node labels created by the test run and then show the labels have been removed.
  echo -e "\nRemoving the node labels"
  oc label nodes ${node_array[1]} cpu-
  oc label nodes ${node_array[2]} cpu-
  oc label nodes ${node_array[1]} --overwrite ${initial_node_label}

  show_node_labels
  exit 0
else
  echo -e "\nOverall Node Affinity and Anti-affinity Testcase result:  FAIL"
  echo "Please debug. When debugging is complete, delete all projects using 'oc delete project -l kube-burner-job=$AFFINTIY_NAME' and 'oc delete project -l kube-burner-job=$ANTI_AFFINTIY_NAME'"
  exit 1
fi