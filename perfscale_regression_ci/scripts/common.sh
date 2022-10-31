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
  my_namespace=$1
  my_nodename=$2

  echo "$(oc get pods -n ${my_namespace} -o wide | grep ${my_nodename} | grep Running | wc -l | xargs)"
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

function prepare_project() {
  project_name=$1
  project_label=$2

  oc new-project project_name
  oc label namespace project_name project_label
}