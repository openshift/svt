#!/bin/bash

##############################################################################
# Author: skordas@redhat.com
# Related Polarion Test Case: OCP-22443
# Description:
# Ensure that you can run the SVT Kitchen Sink Test: cluster-loader.py with master-vert.yaml on restarted Master-1:
#
# This will create 7projects to build and deploy 7 quickstart apps from their respective json templates:
# cakephp-mysq, dancer-mysql, django-postgresql, nodejs-mongodb, rails-postgresql, eap64-mysql, tomcat8-mongodb
#
# Test details can be found in the GitHub SVT openshift_scalability repo:
# https://github.com/openshift/svt/blob/master/openshift_scalability/README.md
# https://github.com/openshift/svt/blob/master/openshift_scalability/config/master-vert.yaml
#
# Run test: bash master-failover-kitchen-sink.sh
# Run test and remove test projects after run: bash master-failover-kitchen-sink.sh true
#
# Changes:
#   skordas: update enable api and controller functions to check if there is 4/4 running
##############################################################################

if [[ $(oc get nodes | grep -c master) -ne 3 ]]; then
  echo "To run this script you need to provide cluster with 3 master nodes"
  exit 1
fi

wait_time=10
number_of_retries=30

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
      echo "On node $1 kube-apiserver is down"
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
      echo "On node $1 kube-controller-manager is down"
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
      echo "On node $1 kube-apiserver is up"
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
      echo "On node $1 kube-controller-manager is up"
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
    # oc get pods -n cakephp-mysql0 | grep Running | grep -v deploy | grep -v build | grep cakephp-mysql-example
    v1=$(oc get pods -n cakephp-mysql0 | grep Running | grep -v deploy | grep -v build | grep -c cakephp-mysql-example)
    # oc get pods -n cakephp-mysql0 | grep Running | grep -v deploy | grep -v build | grep -v cakephp-mysql-example | grep mysql
    v2=$(oc get pods -n cakephp-mysql0 | grep Running | grep -v deploy | grep -v build | grep -v cakephp-mysql-example | grep -c mysql)
    # oc get pods -n dancer-mysql0 | grep Running | grep -v deploy | grep -v build | grep dancer-mysql-example
    v3=$(oc get pods -n dancer-mysql0 | grep Running | grep -v deploy | grep -v build | grep -c dancer-mysql-example)
    # oc get pods -n dancer-mysql0 | grep Running | grep -v deploy | grep -v build | grep database
    v4=$(oc get pods -n dancer-mysql0 | grep Running | grep -v deploy | grep -v build | grep -c database)
    # oc get pods -n django-postgresql0 | grep Running | grep -v deploy | grep -v build | grep django-psql-example
    v5=$(oc get pods -n django-postgresql0 | grep Running | grep -v deploy | grep -v build | grep -c django-psql-example)
    # oc get pods -n django-postgresql0 | grep Running | grep -v deploy | grep -v build | grep postgresql
    v6=$(oc get pods -n django-postgresql0 | grep Running | grep -v deploy | grep -v build | grep -c postgresql)
    # oc get pods -n eap64-mysql0 | grep Running | grep -v deploy | grep -v build | grep -v eap-app-mysql | grep eap-app
    v7=$(oc get pods -n eap64-mysql0 | grep Running | grep -v deploy | grep -v build | grep -v eap-app-mysql | grep -c eap-app)
    # oc get pods -n eap64-mysql0 | grep Running | grep -v deploy | grep -v build | grep eap-app-mysql
    v8=$(oc get pods -n eap64-mysql0 | grep Running | grep -v deploy | grep -v build | grep -c eap-app-mysql)
    # oc get pods -n nodejs-mongodb0 | grep Running | grep -v deploy | grep -v build | grep nodejs-mongodb-example
    v9=$(oc get pods -n nodejs-mongodb0 | grep Running | grep -v deploy | grep -v build | grep -c nodejs-mongodb-example)
    # oc get pods -n rails-postgresql0 | grep Running | grep -v deploy | grep -v build | grep -v rails-postgresql-example | grep postgresql
    v10=$(oc get pods -n rails-postgresql0 | grep Running | grep -v deploy | grep -v build | grep -v rails-postgresql-example | grep -c postgresql)
    # oc get pods -n rails-postgresql0 | grep Running | grep -v deploy | grep -v build | grep rails-postgresql-example
    v11=$(oc get pods -n rails-postgresql0 | grep Running | grep -v deploy | grep -v build | grep -c rails-postgresql-example)
    # oc get pods -n tomcat8-mongodb0 | grep Running | grep -v deploy | grep -v build | grep -v jws-app-mongodb | grep jws-app
    v12=$(oc get pods -n tomcat8-mongodb0 | grep Running | grep -v deploy | grep -v build | grep -v jws-app-mongodb | grep -c jws-app)
    # oc get pods -n tomcat8-mongodb0 | grep Running | grep -v deploy | grep -v build | grep jws-app-mongodb
    v13=$(oc get pods -n tomcat8-mongodb0 | grep Running | grep -v deploy | grep -v build | grep -c jws-app-mongodb)

    if [[ $v1 -eq 1 ]] && [[ $v2 -eq 1 ]] && [[ $v3 -eq 1 ]] && [[ $v4 -eq 1 ]] && \
       [[ $v5 -eq 1 ]] && [[ $v6 -eq 1 ]] && [[ $v7 -eq 1 ]] && [[ $v8 -eq 1 ]] && \
       [[ $v9 -eq 1 ]] && [[ $v10 -eq 1 ]] && [[ $v11 -eq 1 ]] && [[ $v12 -eq 1 ]] && [[ $v13 -eq 1 ]]; then
      echo "All services are up!"
      break
    fi
    ((try=${try}+1))
    if [[ $try -eq $number_of_retries ]]; then
      echo "Not all projects are ready. Check pods with command:"
      echo 'for proj in $(oc get projects --show-labels | grep purpose=test | cut -d " " -f 1); do echo ""; echo $proj; oc get pods -n $proj; done'
      exit 1
    fi
    echo "Ready $((${v1}+${v2}+${v3}+${v4}+${v5}+${v6}+${v7}+${v8}+${v9}+${v10}+${v11}+${v12}+${v13}))/13 services"
    echo "Retrying in $wait_time seconds"
    sleep $wait_time
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
disable_kube_api_server_on_node ${nodes[1]}
disable_kube_controller_manager_on_node ${nodes[1]}

cd ..
./cluster-loader.py -f config/master-vert.yaml
echo "Sleep for one minute"
sleep 60
project_verification
enable_kube_api_server_on_node ${nodes[0]}
enable_kube_controller_manager_on_node ${nodes[0]}
enable_kube_api_server_on_node ${nodes[1]}
enable_kube_controller_manager_on_node ${nodes[1]}

delete_projects $1
