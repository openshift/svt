#!/bin/bash 

if [ "$#" -ne 1 ]; then
  echo "syntax: $0 <TYPE>"
  echo "<TYPE> should be either golang or python"
  exit 1
fi

TYPE=$1

function python_clusterloader() {
  MY_CONFIG=../../config/configCreateLoadedProjects.yaml
  python_v=$(python --version 2>&1 | sed 's/.* \([0-9]\).\([0-9]\).*/\1\2/')
  if [[ $python_v -lt "29" ]]; then
    echo "Running python 2";
  else
    echo "Have python version: $(python --version 2>&1); Need to run with python 2: exiting"
    exit
  fi

  python ../../cluster-loader.py -f $MY_CONFIG
}

function golang_clusterloader() {

  # start GoLang cluster-loader
  export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}
  cur_loc=$(pwd)

  MY_CONFIG=$cur_loc/../../config/golang/configCreateLoadedProjects.yaml

  VIPERCONFIG=$MY_CONFIG openshift-tests run-test "[sig-scalability][Feature:Performance] Load cluster should populate the cluster [Slow][Serial]"

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

function wait_for_running() {
  project_name=$1
  counter=0
  all_pods=$(oc get pods -n ${project_name} | grep pod | wc -l | xargs)
  while true; do
    running_pods=$(oc get pods -n ${project_name} | grep Running | wc -l | xargs)
    echo -e "\nNumber of pods running in namespace ${project_name} is: $running_pods"
    if [[ $all_pods -eq $running_pods ]]; then
      echo "Pods in namespace ${project_name} are Running"
      break
    else
      echo "Pods in namespace ${project_name} are still not running"
    fi

    if [[ $counter == 60 ]]; then
      echo "We still have pods not running in namespace ${project_name}"
      error_exit "We still have pods not running in namespace ${project_name}"
    fi

    ((counter++))
    sleep 5
  done

}

echo -e "\nOCP cluster info:"
oc version
oc get nodes -o wide

oc describe node | grep Runtime

echo -e "\n\n############## Running cluster-loader ######################"
export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}
if [ "$TYPE" == "golang" ]; then
  golang_clusterloader

elif [ "$TYPE" == "python" ]; then

  python_clusterloader
else
  echo "$TYPE is not a valid option, available options: golang, python, atomic"

fi

echo -e "\nFinished executing Cluster-loader"

pods=$(oc get pods --all-namespaces -o wide | grep clusterproject | grep -ci running)
echo -e "\nTotal number of running pods: $pods"

TOTAL_CLUSTERPROJECTS=$(oc get projects | grep -c clusterproject)
echo -e "\nTotal number of clusterproject namespaces created: ${TOTAL_CLUSTERPROJECTS}"

sleep 20

for (( c=0; c<${TOTAL_CLUSTERPROJECTS}; c++ ))
do
  wait_for_running clusterproject${c}
  oc get all -n clusterproject${c}
done

echo -e "\nSleeping for 10 mins"
sleep 600

echo -e "\nDeleting the ${TOTAL_CLUSTERPROJECTS} projects we just created"
for (( c=0; c<${TOTAL_CLUSTERPROJECTS}; c++ ))
do
  oc delete project clusterproject${c}
done

wait_for_project_termination clusterproject
