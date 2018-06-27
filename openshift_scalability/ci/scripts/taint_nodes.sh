#!/bin/bash
# set -x

date
uname -a
openshift version

compute_nodes=$(oc get nodes -l 'node-role.kubernetes.io/compute=true' | awk '{print $1}' | grep -v NAME | xargs)

echo -e "\nComputes nodes are: $compute_nodes"

declare -a node_array
counter=1

oc get nodes -l 'node-role.kubernetes.io/compute=true'
oc describe nodes -l 'node-role.kubernetes.io/compute=true' | grep Taints

# Taint nodes
for n in ${compute_nodes}; do
  node_array[${counter}]=${n}
  echo -e "\nTainting node $n with 'security=s${counter}:NoSchedule'"
  echo "#  oc adm taint nodes $n security=s${counter}:NoSchedule"
  oc adm taint nodes $n security=s${counter}:NoSchedule
  counter=$((counter+1))
done

oc describe nodes -l 'node-role.kubernetes.io/compute=true' | grep Taints

for i in {1..2}; do
  echo "Array element node_array index $i has value : ${node_array[${i}]}"
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

echo -e "\nStarting GoLang cluster-loader with config file: config/golang/node-taints-pod-tolerations"
/usr/libexec/atomic-openshift/extended.test --ginkgo.focus="Load cluster" --viper-config=config/golang/node-taints-pod-tolerations

sleep 30

check_no_error_pods

oc get pods --all-namespaces -o wide

## TO DO:  check running pod counts  and compare to expected counts (250) in cluster loader yaml file
oc get pods -n taints-toleration-s1-0 -o wide | grep "hellopods-taints-s1" | grep ${node_array[1]} | grep Running | wc -l
oc get pods -n taints-toleration-s2-0 -o wide | grep "hellopods-taints-s2" | grep ${node_array[2]} | grep Running | wc -l

# delete projects:  cleanup
oc delete project taints-toleration-s1-0
oc delete project taints-toleration-s2-0

######### TO DO:
######### wait till all pods with tolerations to the tainted nodes are gone

## remove taints previously configured on nodes
echo -e "\nRemoving the previously configured taints on compute nodes"

for i in {1..2}; do
  echo "Removing previously configured taints on node: ${node_array[${i}]}"
  echo "# oc adm taint nodes ${node_array[${i}]} security- "
  oc adm taint nodes ${node_array[${i}]} security-
done

# check taints are gone
oc describe nodes | grep Taints


