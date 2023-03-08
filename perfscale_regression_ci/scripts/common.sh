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

function uncordon_all_nodes() {
  worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker= -o name)
  for worker in ${worker_nodes}; do
    oc adm uncordon $worker
  done
}

# pass $namespace $deployment_name $initial_pod_num $final_pod_num
# e.g. delete_project "test=concurent-job"
function check_deployment_pod_scale()
{
	namespace=$1
	deployment_name=$2
	initial_pod_num=$3
	final_pod_num=$4

	# Sometimes, it takes a while for pods to scale (up or down). Decrement the counter each time we chack for the pods (in 
	# the deployment). The pods should scale before count_scaling reaches a negative value, but if it does become negative, 
	# give an error message and exit the test. This same logic follows for count_running. It takes some time for the pods to 
	# terminate (scale down) or start running (scale up). The pods should all be in a Running state before count_running 
	# reaches a negative value. If count_running ecome negative, give an error message and exit the test.
	count_scaling=1000
	count_running=1000

	while [[ ( $initial_pod_num -ne $final_pod_num ) && ( count_scaling -gt 0 ) ]];
	do 
		oc get deployment $deployment_name  -n $namespace
		initial_pod_num=$(oc get deployment $deployment_name --no-headers -n $namespace | awk -F ' {1,}' '{print $4}' )
		((count_scaling--))
	done

	if [ $count_scaling -lt 0 ]; then
		echo "pods did not not scale to $final_pod_num"
		exit 1
	fi

  pods_not_running=$(oc get pods -n $namespace --no-headers | egrep -v "Completed|Running" | wc -l)
	echo "pods not running (due to scaling): $pods_not_running"

	while [[ ( $count_running -gt 0 ) && ( $pods_not_running -gt 0 ) ]];
	do
		pods_not_running=$(oc get pods -n $namespace --no-headers | egrep -v "Completed|Running" | wc -l)
		((count_running--))
		echo "pods not running: $pods_not_running"
		sleep 3
	done

	if [ $count_running -lt 0 ]; then
		echo "$pods_not_running still not running. Exiting test..."
		exit 1
	fi
}

# pass $expected_status_code $pod_ip $apiserver_pod_name
# e.g. check_http_code $deny_traffic_code $pod_ip $apiserver_pod
function check_http_code(){
	# This applies to the image openshift/hello-openshift:latest
	# When the network traffic is denied and api is called (curl):
	# - the api returns a status code of 000
	# - the script terminates with the exit code 28 with an error message "command terminated with exit code 28".
	#
	# When the network traffic returns and api is called (curl):
	# - the api returns a code of 
	# Hello OpenShift!
	# 200

    my_http_code=$1
    my_pod_ip=$2
  	my_apiserver_pod=$3
	
    for i in {1..120};
	do
		# The command "set +e" allows the script to execute even though the exit code is 28.
        set +e

		# When the traffic is denied, supress the error message by directing the output to "2> /dev/null". 
		http_code=$(eval "oc exec $my_apiserver_pod -n openshift-oauth-apiserver -c oauth-apiserver -- curl -s http://${my_pod_ip}:8080 --connect-timeout 1 -w "%{http_code}" 2> /dev/null")
		
		# Check to see if the status code contains the string "200" (return traffic) or "000" (traffic denied)
		if [[ $http_code = *"$my_http_code"* ]]; then
    		break
		fi
   		sleep 1
	done
	set -e
}

# pass $num1 $num2
# e.g. calculate_difference ${final_time_np} ${final_time_no_np}
function calculate_difference(){
	# Simple function returns the absolue value of the difference b/t two numbers
	value_1=$1
	value_2=$2
	temp_value=$(($value_1-$value_2))
	echo ${temp_value#-}
}