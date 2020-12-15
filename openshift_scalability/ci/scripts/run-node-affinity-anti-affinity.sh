#!/bin/bash
# set -x
if [ "$#" -ne 1 ]; then
  echo "syntax: $0 <TYPE>"
  echo "<TYPE> should be either golang or python"
  exit 1
fi

TYPE=$1

function golang_clusterloader() {
  # Export kube config
  export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}

  #### OCP 4.2: new requirements to run golang cluster-loader from openshift-tests binary:
  ## - Absolute path to config file needed
  ## - .yaml extension is required now in config file name
  ## - full path to the config file  must be under 70 characters total
  MY_CONFIG=../../config/golang/node-affinity.yaml
  # loading cluster based on yaml config file
  VIPERCONFIG=$MY_CONFIG openshift-tests run-test "[sig-scalability][Feature:Performance] Load cluster should populate the cluster [Slow][Serial]"
}

function python_clusterloader() {
  MY_CONFIG=../../config/node-affinity.yaml
  python --version
  python ../../cluster-loader.py -f $MY_CONFIG
}

function show_node_labels() {
  oc get node --show-labels
  oc get node -l cpu=4
  oc get node -l cpu=6
  oc get node -l beta.kubernetes.io/arch=intel
}

function check_no_error_pods()
{
  error=`oc get pods -n $1 | grep Error | wc -l`
  if [ $error -ne 0 ]; then
    echo "$error pods found, exiting"
    #loop to find logs of error pods?
    exit 1
  fi
}

function wait_for_project_termination() {
  COUNTER=0
  terminating=$(oc get projects | grep $1 | grep Terminating | wc -l)
  while [ $terminating -ne 0 ]; do
    sleep 15
    terminating=$(oc get projects | grep $1 | grep Terminating | wc -l)
    echo "$terminating projects are still terminating"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 20 ]; then
      echo "$terminating projects are still terminating after 5 minutes"
      exit 1
    fi
  done
  proj=$(oc get projects | grep $1 | wc -l)
  if [ $proj -ne 0 ]; then
    echo "$proj $1 projects are still there"
    exit 1
  fi
  pods_in_proj=$(oc get pods -A | grep $1 | wc -l)
  if [ $pods_in_proj -ne 0 ]; then
    echo "$pods_in_proj $1 pods are still there"
    exit 1
  fi

}

date
uname -a
oc get clusterversion
oc version
oc get node --show-labels
oc describe node | grep Runtime

compute_nodes=$(oc get nodes -l 'node-role.kubernetes.io/worker=' | awk '{print $1}' | grep -v NAME | xargs)

echo -e "\nWorker  nodes are: $compute_nodes"

declare -a node_array
counter=1

oc get nodes -l 'node-role.kubernetes.io/worker='
oc describe nodes -l 'node-role.kubernetes.io/worker='

initial_node_label="beta.kubernetes.io/arch=amd64"

# Configuration: label nodes  for Affinity and anti-affinity scheduling
for n in ${compute_nodes}; do
  node_array[${counter}]=${n}
  counter=$((counter+1))
done

# output node array elements
for i in {1..2}; do
  echo "Array element node_array index $i has value : ${node_array[${i}]}"
done

# Configuration: label nodes  for Affinity and anti-affinity scheduling
echo -e "\nLabeling node ${node_array[1]} with label 'cpu=4'"
oc label nodes ${node_array[1]} cpu=4

echo -e "\nLabeling node ${node_array[2]} with label 'cpu=6'"
oc label nodes ${node_array[2]} cpu=6

echo -e "\nLabeling node ${node_array[1]} with label 'beta.kubernetes.io/arch=intel'"
oc label nodes ${node_array[1]} --overwrite beta.kubernetes.io/arch=intel

show_node_labels

sleep 5

echo "Run tests"
if [ "$TYPE" == "golang" ]; then
  golang_clusterloader
  pod_counts=$(python -c "import get_pod_total; get_pod_total.get_pod_counts_golang('$MY_CONFIG')")
elif [ "$TYPE" == "python" ]; then
  python_clusterloader
  pod_counts=$(python -c "import get_pod_total; get_pod_total.get_pod_counts_python('$MY_CONFIG')")
else
  echo "$TYPE is not a valid option, available options: golang, python"
  exit 1
fi

sleep 30

check_no_error_pods node-affinity-0

check_no_error_pods node-anti-affinity-0

## Check pod counts expecting <num from yaml> pods per namespace
echo "nodes $node_array"
affinity_pods=$(oc get pods -n node-affinity-0 -o wide | grep "pausepods" | grep ${node_array[2]} | grep Running | wc -l | xargs )
anti_affinity_pods=$(oc get pods -n node-anti-affinity-0 -o wide | grep "hellopods" | grep -v ${node_array[2]} | grep Running | wc -l | xargs)

#validate counts

counts=$(echo $pod_counts | tr ' ' '\n')
declare -a node_namespace
node_affinity_total=0
node_anti_affinity_total=0

counter=0
for n in ${counts}; do
  if [ $((counter % 2)) == 0 ]; then
    echo "counter $counter $n"
    node_namespace=${n}
  else
    if [[ $node_namespace == "node-affinity"* ]]; then
      echo "affinity"
      node_affinity_total=${n}
    elif [[ $node_namespace  == "node-anti-affinity"* ]]; then
      node_anti_affinity_total=${n}
    fi
  fi
  ((counter++))
done

## Pass/Fail
pass_or_fail=0

if [[ ${affinity_pods} == ${node_affinity_total} ]]; then
  echo -e "\nActual ${affinity_pods} pods were sucessfully deployed. Node affinity test passed!"
  ((pass_or_fail++))
else
  echo -e "\nActual ${affinity_pods} pods deployed does NOT match expected ${node_affinity_total} pods for node affinity test.  Node affinity test failed !"
fi

if [[ ${anti_affinity_pods} == ${node_anti_affinity_total} ]]; then
  echo -e "\nActual ${anti_affinity_pods} pods were sucessfully deployed.  Node Anti-affinity test passed!"
  ((pass_or_fail++))
else
  echo -e "\nActual ${anti_affinity_pods} pods deployed does NOT match expected ${node_anti_affinity_total} pods for node Anti-affinity test. Node Anti-affinity test failed !"
fi

counts=$(echo $pod_counts | tr ' ' '\n')
declare -a node_namespace
node_affinity_total=0
node_anti_affinity_total=0

counter=0
for n in ${counts}; do
  if [ $((counter % 2)) == 0 ]; then
    echo "counter $counter $n"
    node_namespace=${n}
  else
    if [[ $node_namespace == "node-affinity"* ]]; then
      echo "affinity"
      node_affinity_total=${n}
    elif [[ $node_namespace  == "node-anti-affinity"* ]]; then
      node_anti_affinity_total=${n}
    fi
  fi
  ((counter++))
done
echo "node_affinity_total $node_affinity_total"
echo "node_anti_affinity_total $node_anti_affinity_total"

## Pass/Fail
pass_or_fail=0

if [[ ${affinity_pods} == ${node_affinity_total} ]]; then
  echo -e "\nActual ${affinity_pods} pods were sucessfully deployed. Node affinity test passed!"
  ((pass_or_fail++))
else
  echo -e "\nActual ${affinity_pods} pods deployed does NOT match expected ${node_affinity_total} pods for node affinity test.  Node affinity test failed !"
fi

if [[ ${anti_affinity_pods} == ${node_anti_affinity_total} ]]; then
  echo -e "\nActual ${anti_affinity_pods} pods were sucessfully deployed.  Node Anti-affinity test passed!"
  ((pass_or_fail++))
else
  echo -e "\nActual ${anti_affinity_pods} pods deployed does NOT match expected ${node_anti_affinity_total} pods for node Anti-affinity test. Node Anti-affinity test failed !"
fi

oc describe node/${node_array[2]}

sleep 60

# delete projects:
######### Clean up: delete projects and wait till all projects and pods are gone
oc delete project node-affinity-0
wait_for_project_termination node-affinity-0

oc delete project node-anti-affinity-0
wait_for_project_termination node-anti-affinity-0

sleep 30

## remove node labels
echo -e "\nRemoving the node labels"
oc label nodes ${node_array[1]} cpu-
oc label nodes ${node_array[2]} cpu-
oc label nodes ${node_array[1]} --overwrite ${initial_node_label}

show_node_labels

## Final Pass/Fail result
if [[ ${pass_or_fail} == 2 ]]; then
  echo -e "\nOverall Node Affinity and Anti-affinity Testcase result:  PASS"
  exit 0
else
  echo -e "\nOverall Node Affinity and Anti-affinity Testcase result:  FAIL"
  exit 1
fi

