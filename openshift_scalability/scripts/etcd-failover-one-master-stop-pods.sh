#!/bin/bash

##############################################################################
# Author: skordas@redhat.com
# Related Polarion Test Case: OCP-22208
# Description:
# Ensure that OpenShift Cluster basic functionality remains available
# when one out of three etcd node service is stopped.
#
# Test details can be found in the GitHub SVT openshift_scalability repo:
# https://github.com/openshift/svt/blob/master/openshift_scalability/README.md
#
# Run test: bash etcd-failover-one-master-stop-pods.sh
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

function disable_etcd_member_on_node {
  echo "Disable etcd-member on node $1"
  oc debug node/$1 -- chroot /host mv /etc/kubernetes/manifests/etcd-member.yaml /root/

  try=0
  while :; do
    oc get pods -o wide -n openshift-etcd -l k8s-app=etcd | grep $1
    number_running_pods=$(oc get pods -o wide -n openshift-etcd -l k8s-app=etcd | grep $1 | grep -c Running)
    if [[ $number_running_pods -eq 0 ]]; then
      echo "etcd-member on node $1 is down"
      break
    fi
    ((try=${try}+1))
    if [[ $try -eq $number_of_retries ]]; then
      echo "On node $1 etcd-member should be down."
      exit 1
    fi
    echo "Pod is not ready. Retrying in $wait_time seconds"
    sleep $wait_time
  done
}

function enable_etcd_member_on_node {
  echo "Enable etcd-member on node $1"
  oc debug node/$1 -- chroot /host mv /root/etcd-member.yaml /etc/kubernetes/manifests/

  try=0
  while :; do
    oc get pods -o wide -n openshift-etcd -l k8s-app=etcd | grep $1
    number_running_pods=$(oc get pods -o wide -n openshift-etcd -l k8s-app=etcd | grep $1 | grep Running | grep -c 2/2)
    if [[ $number_running_pods -eq 1 ]]; then
      echo "etcd-member on node $1 is up!"
      break
    fi
    ((try=${try}+1))
    if [[ $try -eq $number_of_retries ]]; then
      echo "On node $1 etcd-member should be running"
      exit 1
    fi
    echo "Pod is not ready. Retrying in $wait_time seconds"
    sleep $wait_time
  done
}

# Test Run
number_of_pods_before_test=$(oc get pods -A | grep -c Running)
echo "Number of pods before test: $number_of_pods_before_test"

disable_etcd_member_on_node ${nodes[0]}
number_of_pods_during_test=$(oc get pods -A | grep -c Running)
echo "Number of pods during test: $number_of_pods_during_test"
if [[ $number_of_pods_before_test -ne $((${number_of_pods_during_test}+1)) ]]; then
  echo "Number of pods during the test should be less than before test - etcd-member should be down"
  echo "Number of pods before test: $number_of_pods_before_test"
  echo "Number of pods during test: $number_of_pods_during_test"
  exit 1
fi

enable_etcd_member_on_node ${nodes[0]}
number_of_pods_after_test=$(oc get pods -A | grep -c Running)
echo "Number of pods after test:  $number_of_pods_after_test"
if [[ $number_of_pods_before_test -ne $number_of_pods_after_test ]]; then
  echo "Number of pods before test and after should be the same"
  echo "Number of pods before test: $number_of_pods_before_test"
  echo "Number of pods after test:  $number_of_pods_after_test"
  exit 1
fi

