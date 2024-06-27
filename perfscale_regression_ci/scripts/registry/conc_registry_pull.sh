#/!/bin/bash
################################################
## Auth=qili@redhat.com
## Desription: Script to concurrently pull from image registry by scaling up start up application
## Polarion test case: OCP-9226 - Concurrent pull from the registry
## https://polarion.engineering.redhat.com/polarion/redirect/project/OSE/workitem?id=OCP-9226
## Cluster config: 3 master/2 infra/2 registry/200 workers. Type AWS m5.4xlarge (16 vCPU, 64GB RAM). Registry configured to use AWS S3 bucket for persistence
## Registry machineset template: perfscale_regerssion_ci/content/registry-node-machineset-aws.yaml
## Kubeburner config: perfscale_regerssion_ci/kubeburner-object-templates/cakephp-mysql-persistent.yaml
## Parameters: NAMESPACE_COUNT REPLICAS_LIST. e.g. conc_registry_pull.sh 1000 2 5 10 20 40
## ENV variable: SCALE_ONLY. Default false, if set to true, only do scaleup, ignore the registry machineset install and kube-burner.
## ENV variable: CREATE_MOVE_REGISTRY. Default true, if set to false, skip the steps of installing registry machineset and move registry component.
## ENV variable: CLEANUP. Default false, if set to true, will delete the test namespaces.
################################################ 
source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source ../common.sh
source ../../kubeburner-object-templates/openshift-template/cakephp/cakephp-mysql-persistent.env.sh
source conc_registry_pull_env.sh

export SCALE_ONLY=${SCALE_ONLY:-false}
export CREATE_MOVE_REGISTRY=${CREATE_MOVE_REGISTRY:-true}
export CLEANUP=${CLEANUP:-false}

params=($@)
last_index=$((${#params[@]}-1))
first_param=${params[@]:0:1}
rest_params=${params[@]:1:$last_index}
export NAMESPACE_COUNT=${first_param:-2}
export TEST_JOB_ITERATIONS=${NAMESPACE_COUNT}
export REPLICAS_LIST=(${rest_params:-2 5 10})

namespace_prefix=conc-registry-pull
label="kube-burner-job=$namespace_prefix"
results_file=$namespace_prefix-$(date +%Y%m%d%H%M%S).out
database="mysql"
application="cakephp-mysql-persistent"

RESULT=PASS

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

function fix(){
   echo "----Fixing failed builds or deploys----"
  # fixing issues recorded in https://docs.google.com/document/d/148Q-pIZlkZlyqdMDBI3Zr_I10_IDwMcKiBpuwP14lZw/edit#heading=h.nnxdwzdzlvx
  echo "Fixing cakephp-mysql-persistent application that are not running ."
  # resolve mysql replicacontroller not ready by deleting the mysql replicationcontroller and let it recreate
  for namespace in $(oc get rc -A -l openshift.io/deployment-config.name=$database --no-headers| egrep -v '1.*1.*1' | awk '{print $1}'); do
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

echo "====Test started===="
echo "Pass NAMESPACE_COUNT and REPLICAS_LIST as parameters to this script to overwrite the default"
echo "Export SCALE_ONLY and CLEANUP via env variables"
echo "e.g. conc_registry_pull.sh 1000 2 5 10 20 40"
echo "NAMESPACE_COUNT: $NAMESPACE_COUNT"
echo "REPLICAS_LIST:${REPLICAS_LIST[@]}"
echo "SCALE_ONLY: $SCALE_ONLY"
echo "CREATE_MOVE_REGISTRY: $CREATE_MOVE_REGISTRY"
echo "CLEANUP: $CLEANUP"
# only work on aws now
if [[ $SCALE_ONLY != true ]]; then
  if [[ $CREATE_MOVE_REGISTRY == true ]]; then
    create_registry_machinesets ../../content/registry-node-machineset-aws.yaml registry
    move_registry_to_registry_nodes
  fi
  echo "====Deleting namespace with label $label===="
  delete_project_by_label $label
  echo "======Use kube-burner to load the cluster with test objects======"
  # only cakephp-mysql-persistent is supported now
  run_workload

  echo "======Wait for the first application pod running in $NAMESPACE_COUNT namespaces======"
  COUNTER=0
  wait_for_pod_running $NAMESPACE_COUNT 1 10
  result=$?
  while [ $result -eq 1 ]; do
    fix
    wait_for_pod_running $NAMESPACE_COUNT 1 10
    result=$?
    COUNTER=$((COUNTER + 1))
    if [[ $COUNTER -ge 2 ]]; then
      echo "Not all cakephp-mysql-persistent application pods are runing. Please check."
      exit 1
    fi
  done
fi
# Scale up
for replicas in "${REPLICAS_LIST[@]}"; do
  start_time=`date +%s`
  scale_apps $NAMESPACE_COUNT $replicas
  wait_for_pod_running $NAMESPACE_COUNT $replicas 80
  if [[ $? -eq 1 ]]; then
    echo "Not all $replicas replicas for $ns applications are running in time. Please check." | tee -a $results_file
    RESULT=FAILED
  else
    end_time=`date +%s`
    total_time=$(($end_time - $start_time))
    echo "Time taken for scaling up to $replicas replicas for $ns applications : $total_time seconds" | tee -a $results_file
  fi
done

echo "====Results===="
cat $results_file
if [[ $CLEANUP = true ]]; then
  echo "====Cleanup $ns projects===="
  delete_project_by_label $label
fi
if [[ $RESULT = "FAILED" ]]; then
  echo "====Test Failed====" 
  exit 1
else
  echo "====Test Passed====" 
  exit 0
fi
