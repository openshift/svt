#!/bin/bash

##############################################################################
# Author: skordas@redhat.com
# Description:
# Ensure that OpenShift Cluster basic functionality remains available
# when two out of three master node services are stopped.
# Polarion Test Case: OCP-22399
# https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-22399]
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
    oc get pods -o wide -n openshift-kube-apiserver | grep $1 | grep -v guard | grep Running
    number_running_pods=$(oc get pods -o wide -n openshift-kube-apiserver | grep $1 | grep -v guard | grep -c Running)
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
    oc get pods -o wide -n openshift-kube-controller-manager | grep $1 | grep -v guard | grep Running
    number_running_pods=$(oc get pods -o wide -n openshift-kube-controller-manager | grep $1 | grep -v guard | grep -c Running)
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
    oc get pods -o wide -n openshift-kube-apiserver | grep $1 | grep -v guard | grep Running
    number_running_pods=$(oc get pods -o wide -n openshift-kube-apiserver | grep $1 | grep -v guard | grep Running | grep -c 5/5)
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
    oc get pods -o wide -n openshift-kube-controller-manager | grep $1 | grep -v guard | grep Running
    number_running_pods=$(oc get pods -o wide -n openshift-kube-controller-manager | grep $1 | grep -v guard | grep Running | grep -c 4/4)
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
  try=0
  while :; do
    oc get pods -n django | grep Running
    v1=$(oc get pods -n django | grep Running | grep -v deploy | grep -v build | grep postgresql | grep -c 1/1)
    v2=$(oc get pods -n django | grep Running | grep -v deploy | grep -v build | grep django-psql-example | grep -c 1/1)
    if [[ $v1 -eq 1 ]] && [[ $v2 -eq 1 ]]; then
      echo "django service is ready!"
      break
    fi
    ((try=${try}+1))
      if [[ $try -eq $number_of_retries ]]; then
        echo "Project django is not ready!"
        exit 1
      fi
      echo "Retrying in $wait_time seconds"
      sleep $wait_time
  done
}

function deployment_config_verification {
  try=0
  while :; do
    oc get deploymentconfigs django-psql-example -n django
    v1=$(oc get dc django-psql-example -o json | jq ".status.replicas")
    if [[ $v1 -eq 2 ]]; then
        echo "Deployment configs are ready!"
        break
    fi
    ((try=${try}+1))
    if [[ $try -eq $number_of_retries ]]; then
      echo "deployment config is not ready!"
      exit 1
    fi
    echo "Retrying in $wait_time seconds"
    sleep $wait_time
  done
}

# Test Run
disable_kube_api_server_on_node ${nodes[0]}
disable_kube_api_server_on_node ${nodes[1]}
disable_kube_controller_manager_on_node ${nodes[0]}
disable_kube_controller_manager_on_node ${nodes[1]}

oc new-project django
oc new-app --template=django-psql-example
sleep 15
project_verification
oc scale --replicas=2 dc/django-psql-example
sleep 10
deployment_config_verification

enable_kube_api_server_on_node ${nodes[0]}
enable_kube_api_server_on_node ${nodes[1]}
enable_kube_controller_manager_on_node ${nodes[0]}
enable_kube_controller_manager_on_node ${nodes[1]}