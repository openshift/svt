#!/bin/bash
# set -x

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


function show_node_labels() {
  oc get node --show-labels
  oc get node -l cpu=4
  oc get node -l cpu=6
  oc get node -l beta.kubernetes.io/arch=intel
}

function check_no_error_pods()
{
  error=`oc get pods --all-namespaces | grep Error | wc -l`
  if [ $error -ne 0 ]; then
    echo "$error pods found, exiting"
    exit 1
  fi
}

show_node_labels

sleep 5


# start GoLang cluster-loader
export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}

cd /root/svt/openshift_scalability
ls -ltr config/golang

#### OCP 4.2: new requirements to run golang cluster-loader from openshift-tests binary:
## - Absolute path to config file needed
## - .yaml extension is required now in config file name
## - full path to the config file  must be under 70 characters total

MY_CONFIG=/root/svt/openshift_scalability/config/golang/node-affinity.yaml
echo -e "\nRunning GoLang cluster-loader from openshift-tests binary with config file: ${MY_CONFIG}"
echo -e "\nContents of  config file: ${MY_CONFIG}"
cat ${MY_CONFIG}

VIPERCONFIG=$MY_CONFIG openshift-tests run-test "[Feature:Performance][Serial][Slow] Load cluster should load the cluster [Suite:openshift]"

sleep 30

check_no_error_pods

oc get pods --all-namespaces -o wide

## TO DO:  check pod counts expecting 130 pods per namespace
oc get pods -n node-affinity-0 -o wide | grep "pausepods" | grep ${node_array[2]} | grep Running | wc -l
oc get pods -n node-anti-affinity-0 -o wide | grep "hellopods" | grep ${node_array[1]} | grep Running | wc -l

sleep 60

# delete projects:  cleanup
oc delete project node-affinity-0
oc delete project node-anti-affinity-0

######### TO DO:
######### Need to clean up, delete projects and wait till all pods are gone

sleep 30

## remove node labels
echo -e "\nRemoving the node labels"
oc label nodes ${node_array[1]} cpu-
oc label nodes ${node_array[2]} cpu-
oc label nodes ${node_array[1]} --overwrite ${initial_node_label}

show_node_labels


