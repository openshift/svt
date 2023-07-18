###############################################
## Auth=lhorsley@redhat.com
## Description: Cluster resilience testing via creation of a large number of secrets with a specific labelSelector in namespaces on an OWN cluster
## Polarion test case: OCP-41643 - Large object list testing (Listing secrets in all namespaces with a specific labelSelector)	
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-65206
## Bugs related: https://bugzilla.redhat.com/show_bug.cgi?id=2050230 and https://bugzilla.redhat.com/show_bug.cgi?id=2094012
## Cluster config: 3 master (m5.4xlarge or equivalent) with 40 workers (vm_type_workers: m5.2xlarge or equivalent).
## The machine running the test should have at least 4 cores.
## Note: While the test runs, check the functionality of the cluster. A simple example:
##       while true; do oc get co --no-headers| grep -v 'True.*False.*False'; oc get nodes --no-headers| grep -v ' Ready'; date; sleep 10; done
################################################ 

#! /bin/bash

expected_namespaces=${1:-100}
secrets_per_namespace=${2:-10}
expected_secrets=$(( $expected_namespaces * $secrets_per_namespace ))
debug_secrets_command="oc get secrets -A -l test=listobject --no-headers -v9"
my_secret_name="-secret-"
my_namespace="objecttest-"
my_object_type="namespaces"

# simple function to display the status of operators and nodes
function get_operator_and_node_status() {
  echo ""
  echo "Node and operator status check"
  oc get nodes
  echo ""
  oc get co
  echo ""
}

# function to create namespaces and secrets
function create_namespaces_and_secrets() {

  for ((i=0; i<$expected_namespaces; i++)); do
      my_namespace_command='oc new-project --skip-config-write "${my_namespace}${i}" > /dev/null && echo -e "\n\nCreated project ${my_namespace}${i}" &>> object-list-test.log &'
      eval $my_namespace_command
      for ((j=0; j<$secrets_per_namespace; j++)); do
         echo "
         apiVersion: v1
         kind: Secret
         metadata:
           labels:
             test: listobject
           namespace: ${my_namespace}${i}
           name: ${my_namespace}${i}${my_secret_name}${j}
         " | oc apply -f - &>> object-list-test.log &
      done
      sleep 5
  done
}

# function to delete namespaces (and secrets)
function delete_namespaces() {
  my_expected_namespaces=$1
  COUNTER=0  

  for ((i=0; i<$my_expected_namespaces; i++)); do
      my_command='oc delete project "${my_namespace}${i}" >> object-list-test.log &'
      eval $my_command
  done

  existing_obj=$(oc get $my_object_type -A| grep $my_namespace | wc -l)
  while [ $existing_obj -ne 0 ]; do
    sleep 5
    existing_obj=$(oc get $my_object_type -A | grep $my_namespace | wc -l | xargs )
    echo "Waiting for $my_object_type to be deleted: $existing_obj still exist"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 60 ]; then
      echo "$existing_obj $my_object_type are still not deleted after 5 minutes"
      exit 1
    fi
  done
  echo "All $my_object_type are deleted"
}


# Start of the test
# Step 1. Check the cluster for objects created by previous execution of this test. If those objects exist, remove them.
echo "Checking the cluster for test objects..."
check_cluster=$(oc get $my_object_type -A| grep $my_namespace | wc -l)
if [ $check_cluster -ne 0 ]; then
  echo "Removing test objects from the cluster before test execution"
  delete_namespaces $check_cluster
else
  echo "No test objects present..."
fi

echo ""

# Step 2. Start the log file
echo -e "\nWriting subprocess logs to ./object-list-test.log"
if [ -e object-list-test.log ]; then
	echo "object-list-test.log exists, subprocess logs will be appended"
fi

echo -e "\n===========================================" >> object-list-test.log &
echo "$(date) - NEW RUN" >> object-list-test.log &
echo ""


# Step 3. Create the namespaces and the secrets. The output is printed to a log file. Also, we are calculating test object creation time.
echo "$(date) - Namespace and secret creation starting..."
cycle_start_time=`date +%s`
create_namespaces_and_secrets

echo "$(date) - Namespace and secret creation complete."
echo -e "\nNamespace and secret creation complete." >> object-list-test.log &
cycle_end_time=`date +%s` 
total_cycle_time=$((cycle_end_time - cycle_start_time))
echo "Total time for create cycle: $total_cycle_time s."


# Pause to allow the system to catch up
echo -e "\nSleeping for 5 minutes..." | tee object-list-test.log
sleep 5m

echo -e "\nChecking for the namespaces and secrets." | tee object-list-test.log


my_namespace_command='oc get secrets -A -l test=listobject &>> object-list-test.log &'
eval $my_namespace_command


# Find and count all of the secrets created by this test
check_secrets_command="oc get secrets -A -l test=listobject --no-headers | wc -l"
check_namespaces_command='oc get namespaces --no-headers=true -o custom-columns=:metadata.name | grep ${my_namespace} | wc -l'

actual_secrets=$(eval $check_secrets_command)
actual_namespaces=$(eval $check_namespaces_command)

echo "expected # of namespaces: $expected_namespaces" 
echo "actual # of namespaces: $actual_namespaces"
echo "expected # of secrets: $expected_secrets"
echo "actual # of secrets: $actual_secrets"

echo -e "\nCheck for the namespaces and secrets - COMPLETE" | tee object-list-test.log
SCRIPT_DIR=$( cd ${0%/*} && pwd -P )
echo "log output file can be found in same directory as test script: "${SCRIPT_DIR}""

# Find and count operators and nodes in a bad state
bad_operators=$(oc get co --no-headers| grep -v 'True.*False.*False' | wc -l)
nodes_not_ready=$(oc get nodes --no-headers | grep -v Ready | wc -l)

get_operator_and_node_status


# Step 5. Print the test results
echo ""
echo "======Final test result======"
if [[ ( $expected_secrets -eq $actual_secrets ) && ($expected_namespaces -eq $actual_namespaces)  && ($bad_operators -eq 0) && ($nodes_not_ready -eq 0) ]]; then
    echo "Test passed"
    echo "The expected and actual number of namespaces are equal."
    echo "The expected and actual number of secrets are equal"
    echo "Cluster operators are stable."
    echo "All nodes are Ready."
    echo "Removing test objects..."
    delete_namespaces $expected_namespaces
    exit 0
else
    echo "Test failed"
    echo "Operators (oc get co --no-headers| grep -v 'True.*False.*False'):"
    oc get co --no-headers| grep -v 'True.*False.*False'
    echo ""
    echo "Nodes oc get nodes --no-headers | grep -v Ready):"
    oc get nodes --no-headers | grep -v Ready
    echo ""
    echo "expected # of namespaces: $expected_namespaces.  actual # of namespaces: $actual_namespaces"
    echo "expected # of secrets: $expected_secrets.  actual # of secrets: $actual_secrets"
    echo ""
    echo "============================================"
    echo "Getting debug info"
    eval $debug_secrets_command
    exit 1
fi

