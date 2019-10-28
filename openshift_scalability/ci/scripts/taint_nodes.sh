#!/bin/bash
# set -x

date
uname -a
oc version
oc get clusterversion
oc get clusterversion -o json

compute_nodes=$(oc get nodes -l 'node-role.kubernetes.io/worker=' | awk '{print $1}' | grep -v NAME | xargs)


echo -e "\nComputes nodes are: $compute_nodes"

declare -a node_array
counter=1

oc get nodes -l 'node-role.kubernetes.io/worker='
oc describe nodes -l 'node-role.kubernetes.io/worker=' | grep Taints

# Build node_array of workers:
for n in ${compute_nodes}; do
  node_array[${counter}]=${n}
  echo -e "\nArray element node_array index ${counter} has value : ${node_array[${counter}]}"
  counter=$((counter+1))
done

oc describe nodes -l 'node-role.kubernetes.io/worker=' | grep Taints

## Testing with 3 worker nodes
for i in {1..3}; do
  echo "Array element node_array index $i has value : ${node_array[${i}]}"
done

## For OCP 4.x: Taint all 3 worker nodes in node_array:
for i in {1..3}; do
  echo -e "\nTainting node ${node_array[${i}]} with 'security=s${i}:NoSchedule'"
  echo "#  oc adm taint nodes ${node_array[${i}]} security=s${i}:NoSchedule"
  oc adm taint nodes ${node_array[${i}]} security=s${i}:NoSchedule
done


function check_no_error_pods()
{
  error=`oc get pods --all-namespaces | grep Error | wc -l`
  if [ $error -ne 0 ]; then
    echo "$error pods found, exiting"
    exit 1
  fi
}


sleep 5


# start GoLang cluster-loader
export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}

cd /root/svt/openshift_scalability
ls -ltr config/golang

#### OCP 4.2: new requirements to run golang cluster-loader from openshift-tests binary:
## - Absolute path to config file needed
## - .yaml extension is required now in config file name
## - full path to the config file  must be under 70 characters total
MY_CONFIG=/root/svt/openshift_scalability/config/golang/taints-tolerations.yaml
echo -e "\nRunning GoLang cluster-loader from openshift-tests binary with config file: ${MY_CONFIG}"
echo -e "\nContents of  config file: ${MY_CONFIG}"
cat ${MY_CONFIG}
VIPERCONFIG=$MY_CONFIG openshift-tests run-test "[Feature:Performance][Serial][Slow] Load cluster should load the cluster [Suite:openshift]"

sleep 180

check_no_error_pods

oc get pods --all-namespaces -o wide

## TO DO:  check running pod counts  and compare to expected counts (130) in cluster loader yaml file
echo -e "\nAfter deploying pods with cluster-loader, number of Running hellopods-taints-s1 pods on node ${node_array[1]} and in namespace taints-tolerationss1-0 is: "
oc get pods -n taints-tolerationss1-0 -o wide | grep "hellopods-taints-s1" | grep ${node_array[1]} | grep Running | wc -l
echo -e "\nAfter deploying pods with cluster-loader, number of Running hellopods-taints-s2 pods on node ${node_array[2]} and in namespace taints-tolerationss2-0 is: "
oc get pods -n taints-tolerationss2-0 -o wide | grep "hellopods-taints-s2" | grep ${node_array[2]} | grep Running | wc -l
### For OCP 4.1:  added:  05-16-2019
echo -e "\nAfter deploying pods with cluster-loader, number of Running hellopods-taints-s1 pods on node ${node_array[3]} and in namespace taints-tolerationss1-0 is: "
oc get pods -n taints-tolerationss1-0 -o wide | grep "hellopods-taints-s1" | grep ${node_array[3]} | grep Running | wc -l
echo -e "\nAfter deploying pods with cluster-loader, number of Running hellopods-taints-s2 pods on node ${node_array[3]} and in namespace taints-tolerationss2-0 is: "
oc get pods -n taints-tolerationss2-0 -o wide | grep "hellopods-taints-s2" | grep ${node_array[3]} | grep Running | wc -l

sleep 10

# delete projects:  cleanup
oc delete project taints-tolerationss1-0
oc delete project taints-tolerationss2-0

sleep 30

######### TO DO:
######### wait till all pods with tolerations to the tainted nodes are gone

## remove taints previously configured on nodes
echo -e "\nRemoving the previously configured taints on compute nodes"

## For OCP 4.1: remove taints from all 3 worker nodes:
for i in {1..3}; do
  echo "Removing previously configured taints on node: ${node_array[${i}]}"
  echo "# oc adm taint nodes ${node_array[${i}]} security- "
  oc adm taint nodes ${node_array[${i}]} security-
done

# check taints are gone
oc describe nodes | grep Taints



