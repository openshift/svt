#!/bin/bash

##############################################################################
# Author: skordas@redhat.com
# Related Polarion Test Case: OCP-22211
# Description:
# Ensure that OpenShift Cluster basic functionality remains available
# when one out of three master node services are stopped.
#
# Test details can be found in the GitHub SVT openshift_scalability repo:
# https://github.com/openshift/svt/blob/master/openshift_scalability/README.md
#
# Run test: bash master-failover-one-master-stop-pods.sh
#
##############################################################################

if [[ $(oc get nodes | grep -c master) -ne 3 ]]; then
  echo "To run this script you need to provide cluster with 3 master nodes"
  exit 1
fi

wait_time=10
number_of_retries=20

nodes=()
for node in $(oc get nodes | grep master | awk '{print $1}'); do
  nodes+=( $node )
done

function disable_kube_api_server_on_node {
  echo "Disable kube-apiserver on node $1"
  oc debug node/$1 -- chroot /host mv /etc/kubernetes/manifests/kube-apiserver-pod.yaml /root/

  try=0
  while :; do
    oc get pods -o wide -n openshift-kube-apiserver | grep $1 | grep Running
    number_running_pods=$(oc get pods -o wide -n openshift-kube-apiserver | grep $1 | grep -c Running)
    if [[ $number_running_pods -eq 0 ]]; then
      echo "kube-apiserver on node $1 is down"
      break
    fi
    ((try=${try}+1))
    if [[ $try -eq $number_of_retries ]]; then
      echo "On node $1 kube-apiserver should be down."
      exit 1
    fi
    echo "Retrying in $wait_time seconds"
    sleep $wait_time
  done
}

function disable_kube_controller_manager_on_node {
  echo "Disable kube-controller-manager on node $1"
  oc debug node/$1 -- chroot /host mv /etc/kubernetes/manifests/kube-controller-manager-pod.yaml /root/

  try=0
  while :; do
    oc get pods -o wide -n openshift-kube-controller-manager | grep $1 | grep Running
    number_running_pods=$(oc get pods -o wide -n openshift-kube-controller-manager | grep $1 | grep -c Running)
    if [[ $number_running_pods -eq 0 ]]; then
      echo "kube-controller-manager on node $1 is down"
      break
    fi
    ((try=${try}+1))
    if [[ $try -eq $number_of_retries ]]; then
      echo "On node $1 kube-controller-manager should be down."
      exit 1
    fi
    echo "Retrying in $wait_time seconds"
    sleep $wait_time
  done
}

function enable_kube_api_server_on_node {
  echo "Enable kube-apiserver on node $1"
  oc debug node/$1 -- chroot /host mv /root/kube-apiserver-pod.yaml /etc/kubernetes/manifests/

  try=0
  while :; do
    oc get pods -o wide -n openshift-kube-apiserver | grep $1 | grep Running
    number_running_pods=$(oc get pods -o wide -n openshift-kube-apiserver | grep $1 | grep Running | grep -c 4/4)
    if [[ $number_running_pods -eq 1 ]]; then
      echo "kube-apiserver on node $1 is up!"
      break
    fi
    ((try=${try}+1))
    if [[ $try -eq $number_of_retries ]]; then
      echo "On node $1 should be 3 running kube-apiserver pods"
      exit 1
    fi
    echo "Retrying in $wait_time seconds"
    sleep $wait_time
  done
}

function enable_kube_controller_manager_on_node {
  echo "Enable kube-controller-manager no node $1"
  oc debug node/$1 -- chroot /host mv /root/kube-controller-manager-pod.yaml /etc/kubernetes/manifests/

  try=0
  while :; do
    oc get pods -o wide -n openshift-kube-controller-manager | grep $1 | grep Running
    number_running_pods=$(oc get pods -o wide -n openshift-kube-controller-manager | grep $1 | grep Running | grep -c 4/4)
    if [[ $number_running_pods -eq 1 ]]; then
      echo "kube-controller-manager on node $1 is up!"
      break
    fi
    ((try=${try}+1))
    if [[ $try -eq $number_of_retries ]]; then
      echo "On node $1 should be 3 running kube-controller-manager pods"
      exit 1
    fi
    echo "Retrying in $wait_time seconds"
    sleep $wait_time
  done
}

# Test Run
number_of_pods_before_test=$(oc get pods -A | grep -c Running)
echo "Number of pods before test: $number_of_pods_before_test"

disable_kube_api_server_on_node ${nodes[0]}
disable_kube_controller_manager_on_node ${nodes[0]}
number_of_pods_during_test=$(oc get pods -A | grep -c Running)
echo "Number of pods during test: $number_of_pods_during_test"
if [[ $number_of_pods_before_test -ne $((${number_of_pods_during_test}+2)) ]]; then
  echo "Number of pods during the test should be less than before test - kube-apiserver and kube-controller-manager should be down"
  echo "Number of pods before test: $number_of_pods_before_test"
  echo "Number of pods during test: $number_of_pods_during_test"
  exit 1
fi

enable_kube_api_server_on_node ${nodes[0]}
enable_kube_controller_manager_on_node ${nodes[0]}
number_of_pods_after_test=$(oc get pods -A | grep -c Running)
echo "Number of pods after test:  $number_of_pods_after_test"
if [[ $number_of_pods_before_test -ne $number_of_pods_after_test ]]; then
  echo "Number of pods before test and after should be the same"
  echo "Number of pods before test: $number_of_pods_before_test"
  echo "Number of pods after test:  $number_of_pods_after_test"
  exit 1
fi