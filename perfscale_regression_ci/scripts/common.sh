#/!/bin/bash

# pass $name_identifier $number
# e.g. wait_for_job_completion "job-" 100
function wait_for_completion() {
  name_identifier=$1
  number=$2
  COUNTER=0
  completed=$(oc get pods -A | grep $name_identifier | grep -c Completed)
  while [ $completed -lt $number ]; do
    sleep 1
    completed=$(oc get pods -A | grep $name_identifier | grep -c Completed)
    echo "$completed jobs are completed"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 1200 ]; then
      not_completed=$(oc get pods -A | grep $name_identifier | grep -v -c Completed)
      echo "$not_completed pods are still not complete after 20 minutes"
      exit 1
    fi
  done
}

# pass $name_identifier $number
# e.g. wait_for_bound "job-" 100
function wait_for_bound() {
  name_identifier=$1
  number=$2
  COUNTER=0
  bound=0
  while [ $bound -lt $number ]; do
    sleep 3
    bound=$(oc get pvc -A  --no-headers | grep $name_identifier | grep -c Bound)
    echo "$running pvc's are bound"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 400 ]; then
      not_running=$(oc get pvc -A  --no-headers | grep $name_identifier | grep -v -c Bound)
      echo "$not_running pvc are still not bound after 20 minutes"
      exit 1
    fi
  done
  echo "done looping"
}

# pass $name_identifier $object_type
# e.g. wait_for_obj_creation "job-" pod
function wait_for_obj_creation() {
  name_identifier=$1
  object_type=$2

  COUNTER=0
  creating=$(oc get $object_type -A | grep $name_identifier | egrep -c -e "Pending|Creating|Error" )
  while [ $creating -ne 0 ]; do
    sleep 5
    creating=$(oc get $object_type -A |  grep $name_identifier | egrep -c -e "Pending|Creating|Error")
    echo "$creating $object_type are still not running/completed"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 60 ]; then
      echo "$creating $object_type are still not running/complete after 5 minutes"
      break
    fi
  done
}

# pass $name_identifier $object_type
# e.g. wait_for_job_completion "job-" jobs
function wait_for_termination() {
  name_identifier=$1
  object_type=$2

  COUNTER=0
  existing_obj=$(oc get $object_type -A| grep $name_identifier | wc -l)
  while [ $existing_obj -ne 0 ]; do
    sleep 5
    existing_obj=$(oc get $object_type -A | grep $name_identifier | wc -l | xargs )
    echo "Waiting for $object_type to be deleted: $existing_obj still exist"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 60 ]; then
      echo "$existing_obj $object_type are still not deleted after 5 minutes"
      exit 1
    fi
  done
  echo "All $object_type are deleted"
}

# pass $name_identifier $object_type
# e.g. wait_for_job_completion "job-" jobs
function wait_for_obj_creation() {
  name_identifier=$1
  object_type=$2

  COUNTER=0
  creating=$(oc get $object_type -A | grep $name_identifier | egrep -c -e "Pending|Creating|Error" )
  while [ $creating -ne 0 ]; do
    sleep 5
    creating=$(oc get $object_type -A |  grep $name_identifier | egrep -c -e "Pending|Creating|Error")
    echo "$creating $object_type are still not running/completed"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 60 ]; then
      echo "$creating $object_type are still not running/complete after 5 minutes"
      break
    fi
  done
}


# pass $label
# e.g. delete_project "test=concurent-job"
function delete_project_by_label() {
  oc project default
  oc delete projects -l $1 --wait=false --ignore-not-found=true
  while [ $(oc get projects -l $1 | wc -l) -gt 0 ]; do
    echo "Waiting for projects to delete"
    sleep 5
  done
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

function count_running_pods()
{
  name_space=$1
  node_name=$2
  name_identifier=$3

  echo "$(oc get pods -n ${name_space} -o wide | grep ""${name_identifier}"" | grep ${node_name} | grep Running | wc -l | xargs)"
}

function install_dittybopper() 
{
    # Clone and start dittybopper to monitor resource usage over time
    git clone https://github.com/cloud-bulldozer/performance-dashboards.git
    cd ./performance-dashboards/dittybopper
    . ./deploy.sh &>dp_deploy.log & disown
    sleep 60
    cd ../..
    dittybopper_route=$(oc get routes -A | grep ditty | awk -F" " '{print $3}')
    echo "Dittybopper available at: $dittybopper_route \n"
}

function get_storageclass()
{
  for s_class in $(oc get storageclass -A --no-headers | awk '{print $1}'); do
    s_class_annotations=$(oc get storageclass $s_class -o jsonpath='{.metadata.annotations}')
    default_status=$(echo $s_class_annotations | jq '."storageclass.kubernetes.io/is-default-class"')
    if [ "$default_status" = '"true"' ]; then
        echo $s_class
    fi 
  done
}

function prepare_project() {
  project_name=$1
  project_label=$2

  oc new-project $project_name
  oc label namespace $project_name $project_label
}

function get_worker_nodes()
{
  echo "$(oc get nodes -l 'node-role.kubernetes.io/worker=' | awk '{print $1}' | grep -v NAME | xargs)"
}

function get_node_name() {
  worker_name=$(echo $1 | rev | cut -d/ -f1 | rev)
  echo "$worker_name"

}

function get_storageclass()
{
  for s_class in $(oc get storageclass -A --no-headers | awk '{print $1}'); do
    s_class_annotations=$(oc get storageclass $s_class -o jsonpath='{.metadata.annotations}')
    default_status=$(echo $s_class_annotations | jq '."storageclass.kubernetes.io/is-default-class"')
    if [ "$default_status" = '"true"' ]; then
        echo $s_class
    fi 
  done
}
function uncordon_all_nodes() {
  worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker= -o name)
  for worker in ${worker_nodes}; do
    oc adm uncordon $worker
  done
}