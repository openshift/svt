#!/bin/bash

##############################################################################
# Author: skordas@redhat.com
# Related Polarion Test Case: OCP-22421
# Description:
# Ensure you can successfully run cluster-loader.py with pyconfigMasterVertScale.yaml
# when one out of three master nodes services are stopped.
#
# This will create 5 projects each with builds:
# buildconfigs, imagestreams, deployment configs, secrets,  routes,
# replicationcontrollers, etc.  from pause-pod based templates.
#
# Test details can be found in the GitHub SVT openshift_scalability repo:
# https://github.com/openshift/svt/blob/master/openshift_scalability/README.md
# https://github.com/openshift/svt/blob/master/openshift_scalability/config/pyconfigMasterVirtScalePause.yaml
#
# Run test: bash master-failover-one-master-stop.sh
# Run test and remove test projects after run: bash master-failover-one-master-stop.sh true
##############################################################################

if [[ $(oc get nodes | grep -c master) -ne 3 ]]; then
  echo "To run this script you need to provide cluster with 3 master nodes"
  exit 1
fi

project_name="clusterproject"
wait_time=5
number_of_retries=10

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
    number_running_pods=$(oc get pods -o wide -n openshift-kube-apiserver | grep $1 | grep Running | grep -c 3/3)
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
    number_running_pods=$(oc get pods -o wide -n openshift-kube-controller-manager | grep $1 | grep Running | grep -c 3/3)
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

function project_verification {
  for project in $(oc get projects | grep $project_name | awk '{print $1}'); do
    echo "Project: $project"
    try=0
    while :; do
      oc get pods -n $project | grep buildconfig0-1-build
      v1=$(oc get pods -n $project | grep -c buildconfig0-1-build)
      oc get pods -n $project | grep Running | grep deploymentconfig0-1
      v2=$(oc get pods -n $project | grep Running | grep -c deploymentconfig0-1)
      oc get pods -n $project | grep Running | grep deploymentconfig1-1
      v3=$(oc get pods -n $project | grep Running | grep -c deploymentconfig1-1)
      oc get pods -n $project | grep Running | grep deploymentconfig2v0-1
      v4=$(oc get pods -n $project | grep Running | grep -c deploymentconfig2v0-1)
      if [[ $v1 -eq 1 ]] && [[ $v2 -eq 1 ]] && [[ $v3 -eq 1 ]] && [[ $v4 -eq 2 ]]; then
        echo "All services are up!"
        break
      fi
      ((try=${try}+1))
      if [[ $try -eq $number_of_retries ]]; then
        echo "In project $project not all pods are ready!"
        exit 1
      fi
      echo "Retrying in $wait_time seconds"
      sleep $wait_time
    done
  done
}

function delete_projects {
  if [[ ! -z "$1" ]] && [[ $(echo "$1" | awk '{print tolower($0)}') = "true" ]]; then
    echo "Deleting projects"
    oc delete project -l purpose=test
  else
    echo "Test projects are not deleted"
    oc get projects --show-labels | grep purpose=test
  fi
}

# Test Run
disable_kube_api_server_on_node ${nodes[0]}
disable_kube_controller_manager_on_node ${nodes[0]}
cd ..
./cluster-loader.py -f config/pyconfigMasterVertScale.yaml
echo "Sleep for 10 seconds"
sleep 10
project_verification
enable_kube_api_server_on_node ${nodes[0]}
enable_kube_controller_manager_on_node ${nodes[0]}
delete_projects $1
