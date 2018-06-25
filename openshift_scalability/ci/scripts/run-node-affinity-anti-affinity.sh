#!/bin/bash
# set -x

date
uname -a
openshift version
oc version
oc get node --show-labels
oc describe node | grep Runtime


compute_nodes=$(oc get nodes -l 'node-role.kubernetes.io/compute=true' | awk '{print $1}' | grep -v NAME | xargs)

echo -e "\nComputes nodes are: $compute_nodes"

declare -a node_array
counter=1

oc get nodes -l 'node-role.kubernetes.io/compute=true'
oc describe nodes -l 'node-role.kubernetes.io/compute=true' 

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

echo -e "\nStarting GoLang cluster-loader with config file: config/golang/node-affinity-anti-affinity"
/usr/libexec/atomic-openshift/extended.test --ginkgo.focus="Load cluster" --viper-config=config/golang/node-affinity-anti-affinity

sleep 30

check_no_error_pods

oc get pods --all-namespaces -o wide

## TO DO:  check counts and later chage 10 to 250 in cluster loader yaml file
oc get pods -n node-affinity-0 -o wide | grep "pausepods" | grep ${node_array[2]} | grep Running | wc -l
oc get pods -n node-anti-affinity-0 -o wide | grep "hellopods" | grep ${node_array[1]} | grep Running | wc -l

sleep 30

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


