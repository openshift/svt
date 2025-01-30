#/!/bin/bash

# wait for object type to get created
# pass $obj_identifier
# e.g. wait_for_object_type "
function wait_for_object_type() {
  object_type=$1
  COUNTER=0
  get_objects=$(oc get $object_type -A 2>&1)
  echo "get object response: $get_objects"
  while [[ $get_objects == *"the server doesn't have a resource type"* ]]; do
    echo "get object response2:  $get_objects"
    sleep 1
    get_objects=$(oc get $object_type -A 2>&1)
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 1200 ]; then
      echo "$object_type object type still does not exist"
      exit 1
    fi
  done
}


function count_running_pods_name()
{
  name_space=$1
  name_identifier=$2
  completed=$(oc get pods -A | grep $name_identifier | grep -c Completed)
  while [ $completed -lt $number ]; do
    echo "$(oc get pods -n ${name_space} -o wide | grep ${name_identifier} | grep Running | wc -l | xargs)"
  done
}


# pass $name_identifier $number
# e.g. wait_for_completion "job-" 100
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
  echo "Object $name_identifier is done creating"
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

# pass $label $filename
# e.g. delete_project "test=concurent-job" delete_status.out
function delete_projects_time_to_file() { 

  delete_file=$2
  start_time=`date +%s`
  delete_project_by_label $1
  stop_time=`date +%s`
  total_time=`echo $stop_time - $start_time | bc`
  echo "Deletion Time - $total_time" >> $delete_file

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


function wait_for_pod_running() {
  namespaces=$1
  replicas=$2
  retry=$3
  pod_number=$(($namespaces*$replicas))
  echo "====Waiting for $replicas replicas to be running in $namespaces projects===="
  COUNTER=0
  running=$(oc get po -A -l deploymentconfig=$application | grep -c Running)
  echo "Current running pods number: $running. Expected pods number: $pod_number."
  while [ $running -ne $pod_number ]; do
    sleep 30
    running=$(oc get po -A -l deploymentconfig=$application | grep -c Running)
    echo "Current running pods number: $running. Expected pods number: $pod_number."
    COUNTER=$((COUNTER + 1))
    if [[ $COUNTER -ge $retry ]]; then
      echo "Running applications are still not reach expected number $pod_number after $retry retry, $((30*$retry))s"
      echo "Not Running applications:"
      oc get po -A -l deploymentconfig=$application | grep -v Running
      break
    fi
  done
  if [ $COUNTER -ge $retry ];then
    return 1
  else
    echo "wait_for_pod_running passed in $((30*$retry))s"
    return 0
  fi
}

function wait_for_app_pod_running() {
  namespace=$1
  replicas=$2
  application=$3

  echo "====Waiting for $replicas replicas to be running in $namespace projects===="
  COUNTER=0

  oc get pods -n $namespace -l app=$application --no-headers | grep Running
  running=$(oc get pods -n $namespace -l app=$application --no-headers | grep Running | wc -l | xargs)
  echo "Current running pods number: $running. Expected pods number: $replicas."
  while [ $running -ne $replicas ]; do
    sleep 5
    running=$(oc get po -n $namespace -l app=$application | grep Running | wc -l | xargs)
    echo "Current running pods number: $running. Expected pods number: $replicas."
    COUNTER=$((COUNTER + 1))
    if [[ $COUNTER -ge 15 ]]; then
      echo "Running applications are still not reach expected number $replicas after $retry retry, $((30*$retry))s"
      echo "Not Running applications:"
      oc get pods -n $namespace -l app=$application | grep -v Running
      break
    fi
  done
  if [ $COUNTER -ge $retry ]; then
    return 1
  else
    echo "wait_for_pod_running passed in $((30*$retry))s"
    return 0
  fi
}

function fix(){
   echo "----Fixing failed builds or deploys----"
  # fixing issues recorded in https://docs.google.com/document/d/148Q-pIZlkZlyqdMDBI3Zr_I10_IDwMcKiBpuwP14lZw/edit#heading=h.nnxdwzdzlvx
  echo "Fixing cakephp-mysql-persistent application that are not running ."
  # resolve mysql replicacontroller not ready by deleting the mysql replicationcontroller and let it recreate
  for namespace in $(sum(node_namespace_pod_container:container_memory_working_set_bytes{cluster="", node=~"ip-10-0-167-50.us-east-2.compute.internal"}) by (pod)
 | awk '{print $1}'); do
    oc get rc -n $namespace
    echo "----Recreate mysql replicacontrollers in namespace $namespace----"
    oc delete rc -l openshift.io/deployment-config.name=$database -n $namespace
  done
  echo "Sleep 120s to let mysql databae pod to start and let cakephp-mysql-persistent deploy to succeed"
  sleep 120
  # resolve the cakephp-mysql-persistent build error by triggering a new build
  for namespace in $(oc get po -A -l openshift.io/build.name=cakephp-mysql-persistent-1 --no-headers| egrep -v "Running|Completed" | awk '{print $1}'); do
    oc get all -n $namespace
    echo "----Rebuild the buildconfig in namespace $namespace----"
    oc start-build cakephp-mysql-persistent -n $namespace
  done
  # resolve cakephp-mysql-persistent replicacontroller not ready by deleting the cakephp-mysql-persistent replicationcontroller and let it recreate
  for namespace in $(oc get rc -A -l openshift.io/deployment-config.name=$application --no-headers| egrep -v '1.*1.*1' | awk '{print $1}'); do
    oc get rc -n $namespace
    echo "----Recreate cakephp-mysql-persistent replicacontrollers in namespace $namespace----"
    oc delete rc -l openshift.io/deployment-config.name=$application -n $namespace
  done
}

function scale_apps() {
  namespaces=$1
  replicas=$2
  echo "====`date`: Scaleing up to $replicas replicas for applications in $namespaces namespaces===="
  for i in $(seq 1 $namespaces); do
    # echo "Scaleing up to $replicas replicas for applications in namespaces $namespace_prefix-$i."
    oc scale deploymentconfig.apps.openshift.io/cakephp-mysql-persistent --replicas $replicas -n $namespace_prefix-$i >/dev/null 2>&1
  done
  echo "====`date`: Scaleing up to $replicas replicas for applications in $namespaces namespaces finished===="
}


function count_running_pods()
{
  name_space=$1
  node_name=$2
  name_identifier=$3

  echo "$(oc get pods -n ${name_space} -o wide | grep ""${name_identifier}"" | grep ${node_name} | grep Running | wc -l | xargs)"
}

function count_running_pods_all()
{
  node_name=$1
  name_identifier=$2

  echo "$(oc get pods -A -o wide | grep ""${name_identifier}"" | grep ${node_name} | grep Running | wc -l | xargs)"
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



function cordon_num_nodes() {
  worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker= -o name)
  for worker in ${worker_nodes}; do
    if [[ $i -lt $1 ]]; then
      first_worker=$worker
    else
      oc adm cordon $worker
      last_worker=$worker
    fi
    i=$((i + 1))
  done

}


function create_registry_machinesets(){
  template=$1
  role=$2
  node_label=node-role.kubernetes.io/$2=
  if [[ $(oc get machinesets -n openshift-machine-api -l machine.openshift.io/cluster-api-machine-type=registry --no-headers | wc -l) -ge 1 ]]; then
    echo "warning: registry machineset already exist"
    oc get machinesets -n openshift-machine-api -l machine.openshift.io/cluster-api-machine-type=registry
    return 1
  fi
  echo "====Creating and labeling nodes===="
  export ROLE=$role
  export OPENSHIFT_NODE_VOLUME_IOPS=0
  export OPENSHIFT_NODE_VOLUME_SIZE=100
  export OPENSHIFT_NODE_VOLUME_TYPE=gp2
  export OPENSHIFT_NODE_INSTANCE_TYPE=m5.4xlarge
  export CLUSTER_NAME=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index (index .items 0).metadata.labels "machine.openshift.io/cluster-api-cluster" )}}')
  if [[ $(oc get machineset -n openshift-machine-api $(oc get machinesets -A  -o custom-columns=:.metadata.name | shuf -n 1) -o=jsonpath='{.metadata.annotations}' | grep -c "machine.openshift.io") -ge 1 ]]; then
    export MACHINESET_METADATA_LABEL_PREFIX=machine.openshift.io
  else
    export MACHINESET_METADATA_LABEL_PREFIX=sigs.k8s.io
  fi
  export AMI_ID=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index .items 0).spec.template.spec.providerSpec.value.ami.id}}')
  export CLUSTER_REGION=$(oc get machineset -n openshift-machine-api -o=go-template='{{(index .items 0).spec.template.spec.providerSpec.value.placement.region}}')
  envsubst < $1 | oc apply -f -

  retries=0
  attempts=60
  while [[ $(oc get nodes -l $node_label --no-headers -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep True | wc -l ) -lt 1 ]]; do
      oc get nodes -l $node_label --no-headers -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep True | wc -l 
      oc get nodes -l $node_label
      oc get machines -A | grep registry
      oc get machinesets -A | grep registry
      sleep 30
      ((retries += 1))
      if [[ ${retries} -gt ${attempts} ]]; then
          echo "error: workload nodes didn't become READY in time, failing"
          print_node_machine_info $role
          exit 1
      fi
  done

  oc label nodes --overwrite -l $node_label node-role.kubernetes.io/worker-
  oc get nodes | grep $role
  return 0
}

function print_node_machine_info() {
    node_label=$1
    for node in $(oc get nodes --no-headers -l node-role.kubernetes.io/$node_label= | egrep -e "NotReady|SchedulingDisabled" | awk '{print $1}'); do
        oc describe node $node
    done
    for machine in $(oc get machines -n openshift-machine-api --no-headers -l machine.openshift.io/cluster-api-machine-type=$node_label| grep -v "Running" | awk '{print $1}'); do
        oc describe machine $machine -n openshift-machine-api
    done
}

function move_registry_to_registry_nodes(){
  echo "====Moving registry to registry nodes===="
  oc patch configs.imageregistry.operator.openshift.io/cluster -p '{"spec": {"nodeSelector": {"node-role.kubernetes.io/registry": ""}}}' --type merge
  oc rollout status deployment image-registry -n openshift-image-registry
  oc get po -o wide -n openshift-image-registry | egrep ^image-registry
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
	count_scaling=200
	count_running=200

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