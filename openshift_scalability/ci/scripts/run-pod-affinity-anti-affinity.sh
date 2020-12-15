#!/bin/bash
# set -x

if [ "$#" -ne 1 ]; then
  echo "syntax: $0 <TYPE>"
  echo "<TYPE> should be either golang or python"
  exit 1
fi

TYPE=$1

date
uname -a
oc get clusterversion
oc version
oc get node --show-labels
oc describe node | grep Runtime

current_date=$(date +%Y-%m-%d-%H%M)
echo "Date timestamp used for s1 pod spec filename: ${current_date}"

total_pods=130
echo "Expecting ${total_pods} pods to be deployed successfully for Pod Affinity and also for Pod Anti-Affinity tests"

function golang_clusterloader() {

  # start GoLang cluster-loader
  export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}
  cur_loc=$(pwd)

  #### OCP 4.2: new requirements to run golang cluster-loader from openshift-tests binary:
  ## - Absolute path to config file needed
  ## - .yaml extension is required now in config file name
  ## - full path to the config file  must be under 70 characters total

  MY_CONFIG=$cur_loc/../../config/golang/pod-affinity.yaml
  #  echo -e "\nRunning GoLang cluster-loader from openshift-tests binary with config file: ${MY_CONFIG}"
  #  echo -e "\nContents of  config file: ${MY_CONFIG}"
  #cat ${MY_CONFIG}

  VIPERCONFIG=$MY_CONFIG openshift-tests run-test "[sig-scalability][Feature:Performance] Load cluster should populate the cluster [Slow][Serial]"

}

function python_clusterloader() {
  MY_CONFIG=../../config/pod-affinity.yaml
  python --version
  python ../../cluster-loader.py -f $MY_CONFIG
}

# An error exit function
function error_exit() {
  echo "$1" 1>&2
  exit 1
}

function wait_for_running() {
  counter=0
  while true; do
    all_running=1

    oc get pods -n s1-proj -o wide
    RUNNING=$(oc get pods -n s1-proj)
    echo "Pod status in namespace s1-proj: ${RUNNING}"
    if [[ $RUNNING =~ Running ]]; then
      oc get pods -n s1-proj -o wide
      echo "Pod s1 in namespace s1-proj is now Running"
    else
      all_running=0
      echo "Pod s1 in namespace s1-proj is still not Running"
    fi

    if [ $all_running -eq 1 ]; then
      break
    fi

    if [[ $counter == 10 ]]; then
      echo "s1 pod failed to get into Running state"
      error_exit "s1 pod failed to get into Running state"
    fi

    ((counter++))
    sleep 15
  done

}

function wait_for_project_termination() {
  COUNTER=0
  terminating=$(oc get projects | grep $1 | wc -l)
  while [ $terminating -ne 0 ]; do
    sleep 15
    terminating=$(oc get projects | grep $1 | wc -l)
    echo "$terminating projects are still there"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 20 ]; then
      echo "$terminating projects are still there after 5 minutes"
      exit 1
    fi
  done
}

function wait_for_terminating() {
  project_name=$1
  counter=0
  while true; do
    still_terminating=0

    TERMINATING=$(oc get pods -n ${project_name})
    echo -e "\nPod status in namespace ${project_name} is: \n${TERMINATING}"
    if [[ $TERMINATING =~ Terminating ]]; then
      still_terminating=1
      echo "Pods in namespace ${project_name} are still Terminating"
    else
      still_terminating=0
      echo "No more Terminating pods in namespace ${project_name}"
    fi

    if [ $still_terminating -eq 0 ]; then
      break
    fi

    if [[ $counter == 60 ]]; then
      echo "We still have pods Terminating in namespace ${project_name}"
      error_exit "We still have pods Terminating in namespace ${project_name}"
    fi

    ((counter++))
    sleep 15
  done

}

function clean_up() {
  oc delete project s1-proj
  rm -f pod-s1-${current_date}.yaml
  wait_for_terminating s1-proj
  wait_for_project_termination s1-proj

}

worker_nodes=$(oc get nodes -l 'node-role.kubernetes.io/worker=' | awk '{print $1}' | grep -v NAME | xargs)

echo -e "\nWorker  nodes are: $worker_nodes"

oc get nodes -l 'node-role.kubernetes.io/worker='
oc describe nodes -l 'node-role.kubernetes.io/worker='

echo -e "apiVersion: v1
kind: Pod
metadata:
  name: s1
  labels:
    security: s1
spec:
  containers:
  - name: ocp
    image: docker.io/ocpqe/hello-pod" > pod-s1-${current_date}.yaml

ls -ltr pod-s1-${current_date}.yaml
cat pod-s1-${current_date}.yaml

#create a new project
oc new-project s1-proj

oc create -f pod-s1-${current_date}.yaml

oc get pods -n s1-proj -o wide

wait_for_running

# capture node where s1 pod was deployed on
s1pod_node=$(oc get pods -n s1-proj -o wide --no-headers | awk {'print $7}')

echo -e "\nPod s1 was deployed on node ${s1pod_node}"

sleep 30

oc project default

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

counts=$(echo $pod_counts | tr ' ' '\n')
declare -a pod_namespace
declare -a pod_counts
pod_affinity_total=0
pod_anti_affinity_total=0

counter=0
for n in ${counts}; do
  if [ $((counter % 2)) == 0 ]; then
    echo "counter $counter $n"
    pod_namespace=${n}
  else
    if [[ $pod_namespace == "pod-affinity"* ]]; then
      echo "affinity"
      pod_affinity_total=${n}
    elif [[ $pod_namespace  == "pod-anti-affinity"* ]]; then
      pod_anti_affinity_total=${n}
    fi
  fi
  ((counter++))
done
echo "pod_affinity_total $pod_affinity_total"
echo "pod_anti_affinity_total $pod_anti_affinity_total"
cluster_loader_result=$?
echo -e "\nClusterLoader return status: ${cluster_loader_result}"

sleep 30

oc get pods --all-namespaces -o wide

echo -e "\n============= Summary of pod count with affinity to s1 pod: =================="
oc get pods -n pod-affinity-s1-0 -o wide | grep "pod-affinity-security-in-s1" | grep ${s1pod_node}

s1_affinity_pod_count=$(oc get pods -n pod-affinity-s1-0 -o wide | grep "pod-affinity-security-in-s1" | grep ${s1pod_node} | grep Running | wc -l | xargs)
echo -e "\nNumber of hellopods deployed with pod affinity to pod s1:  ${s1_affinity_pod_count} , expecting ${pod_affinity_total} pods"

echo -e "\n============= Summary of pod count with anit-affinity to s1 pod: =================="
oc get pods -n pod-anti-affinity-s1-0 -o wide | grep "pod-anti-affinity-security-in-s1" | grep -v ${s1pod_node}

s1_anti_affinity_pod_count=$(oc get pods -n pod-anti-affinity-s1-0 -o wide | grep "pod-anti-affinity-security-in-s1" | grep -v ${s1pod_node} | grep Running | wc -l | xargs)
echo -e "\nNumber of hellopods deployed with pod anti-affinity to pod s1 on nodes other than ${s1pod_node} is : ${s1_anti_affinity_pod_count} , expecting ${pod_anti_affinity_total} pods"

oc describe node/${s1pod_node}

## Pass/Fail
pass_or_fail=0

if [[ ${s1_affinity_pod_count} == ${pod_affinity_total} ]]; then
  echo -e "\nActual ${s1_affinity_pod_count} pods were sucessfully deployed. Pod affinity test passed!"
  ((pass_or_fail++))
else
  echo -e "\nActual ${s1_affinity_pod_count} pods deployed does NOT match expected ${pod_affinity_total} pods for pod affinity test.  Pod affinity test failed !"
fi

if [[ ${s1_anti_affinity_pod_count} == ${pod_anti_affinity_total} ]]; then
  echo -e "\nActual ${s1_anti_affinity_pod_count} pods were sucessfully deployed.  Pod Anti-affinity test passed!"
  ((pass_or_fail++))
else
  echo -e "\nActual ${s1_anti_affinity_pod_count} pods deployed does NOT match expected ${pod_anti_affinity_total} pods for pod Anti-affinity test.  Pod Anti-affinity test failed !"
fi

sleep 60

# delete projects:  cleanup
echo -e "\nCleaning up:  deleting projects and removing temp s1 pod template ..."
oc delete project pod-affinity-s1-0
oc delete project pod-anti-affinity-s1-0
clean_up
sleep 30
echo -e "\nWaiting for pods to terminate ..."
wait_for_terminating pod-affinity-s1-0
wait_for_terminating pod-anti-affinity-s1-0
wait_for_project_termination pod-affinity-s1-0
wait_for_project_termination pod-anti-affinity-s1-0

# Allow for more time to termiante all resources in deleted projects
# This helps if running back-toback tests or CI jenkins job
sleep 60

## Final Pass/Fail result
if [[ ${pass_or_fail} == 2 ]]; then
  echo -e "\nOverall Affinity and Anti-affinity Testcase result:  PASS"
  exit 0
else
  echo -e "\nOverall Affinity and Anti-affinity Testcase result:  FAIL"
  exit 1
fi
