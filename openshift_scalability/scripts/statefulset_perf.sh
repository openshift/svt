#/!/bin/bash
################################################
## Auth=prubenda@redhat.com
## Desription: Script for creating statefulsets per node and checking the status of created pods
###############################################


function rewrite_yaml() {
  # params: num projects, template num, file name
  python -c "from pod_density import increase_pods; increase_pods.print_new_yaml($1,'$3')"
  python -c "from pod_density import increase_pods; increase_pods.print_new_yaml_temp($2,'$3')"
}

function delete_projects() {
  echo "deleting projects"
  oc delete project -l purpose=test --wait=false
  wait_for_project_termination
}

function create_projects() {
  echo "create projects variable $1: $2"
  python ../cluster-loader.py -f $1 -v
}

function wait_for_project_termination() {
  COUNTER=0
  terminating=$(oc get projects | grep clusterproject | grep Terminating | wc -l)
  while [ $terminating -ne 0 ]; do
    sleep 5
    terminating=$(oc get projects | grep clusterproject | grep Terminating | wc -l)
    echo "$terminating projects are still terminating"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 60 ]; then
      echo "$terminating projects are still terminating after 5 minutes"
      exit 1
    fi
  done

}

function wait_for_running_pods() {
  COUNTER=0
  creating=$(oc get pods --all-namespaces | grep clusterproject | grep -v -c Running )
  while [ $creating -ne 0 ]; do
    sleep 5
    creating=$(oc get pods --all-namespaces | grep clusterproject | grep -v -c Running)
    echo "$creating pods are still not running"
    if [ $COUNTER -eq 15 ]; then
      describe_nodes
    fi
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 60 ]; then
      echo "$creating pods are still not running after 5 minutes"
      break
    fi
  done
}


function describe_nodes() {
  COUNTER=0
  nodes=$(oc get nodes -l 'node-role.kubernetes.io/worker='  | awk '{print $1}'| grep -v NAME )
  for node_name in $nodes
  do
    oc describe node $node_name

  done
}

CONFIG_FILE=../config/pyconfigStatefulSet.yaml

#1 project with 60 templates in ../config/pyconfigStatefulSet.yaml
rewrite_yaml 1 75 $CONFIG_FILE

create_projects $CONFIG_FILE

wait_for_running_pods

describe_nodes

delete_projects

rewrite_yaml 75 1 $CONFIG_FILE

create_projects $CONFIG_FILE

wait_for_running_pods

describe_nodes

delete_projects




