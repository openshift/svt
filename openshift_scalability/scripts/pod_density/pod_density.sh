#/!/bin/bash
################################################
## Auth=prubenda@redhat.com
## Desription: Script for running pod density of different number of projects
################################################

outputfile=pod_density.out
process_num=5
scale_num=22
project_num=2000

if [ "$#" -lt 1 ]; then
  echo "syntax: $0 <deployment_file_name>"
  exit 1
fi
loader_file=$1

#optional parameters
while [[ $# -gt 1 ]]
do
key="$1"
echo "key $key"

case $key in
    -s|--scale_num)
    scale_num=$2
    echo "scale $scale_num"
    shift # past argument
    shift # past value
    ;;
    -cp|--cluster_processes)
    process_num=$2
    echo "process_num $process_num"
    shift # past argument
    shift # past value
    ;;
    -p|--projects)
    project_num=$2
    shift
    shift
    ;;
    *)    # unknown option
    #need to get past file
    shift # past arg
    ;;
esac
done

function delete_projects() {
  echo "deleting projects"
  oc delete project -l purpose=test --wait=false
}

function create_projects() {
  echo "create projects variable $1: $2"
  python ../../cluster-loader.py -f $1 -p $2
}

function see_if_error() {
  echo "see if errors $1"
  echo "import pod_density_helper; pod_density_helper.check_error($1)"
  python -c "import pod_density_helper; pod_density_helper.check_error('$1')"
}

function scale_up() {
  echo "scale up"
  python -c "import pod_density_helper; pod_density_helper.edit_machine_sets($1)"
}

function wait_for_pod_creation() {
  COUNTER=0
  creating=$(oc get pods --all-namespaces | grep svt | grep "1-deploy" | grep -v -c Completed)
  while [ $creating -ne 0 ]; do
    sleep 5
    creating=$(oc get pods --all-namespaces | grep svt | grep "1-deploy" | grep -v -c Completed)
    echo "$creating pods are still not completed"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 60 ]; then
      echo "$creating pods are still not complete after 5 minutes"
      break
    fi
  done
}

function pods_per_node() {
  echo "get pods per node"
  python -c 'import pod_density_helper; pod_density_helper.pods_in_nodes()'
}

function rewrite_yaml() {
  python -c "import increase_pods; increase_pods.print_new_yaml($project_num,'$loader_file')"
}

function wait_for_project_termination() {
  COUNTER=0
  terminating=$(oc get projects | grep svt | grep Terminating | wc -l)
  while [ $terminating -ne 0 ]; do
    sleep 15
    terminating=$(oc get projects | grep svt | grep Terminating | wc -l)
    echo "$terminating projects are still terminating"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 20 ]; then
      echo "$terminating projects are still terminating after 5 minutes"
      exit 1
    fi
  done
  svt_proj=$(oc get projects | grep svt- | wc -l)
  if [ $svt_proj -ne 0 ]; then
    echo "$svt_proj svt projects are still there"
    exit 1
  fi
  pods=$(oc get pods -A | grep svt- | wc -l)
  if [ $pods -ne 0 ]; then
    echo "$pods svt pods are still there"
    exit 1
  fi

}

function set_default_project() {
  oc project default
}


function set_cordon_nodes() {
  prom_nodes=$(oc get pods -A -o wide | grep prometheus-k8s |  awk  '{print $8}')
  for node in $prom_nodes; do
    oc adm cordon $node
  done
}

rm -rf $outputfile
echo "Starting pod density $now" >>$outputfile
scale_up $scale_num
set_cordon_nodes
set_default_project
delete_projects
wait_for_project_termination
rewrite_yaml
SECONDS=0
create_projects "$loader_file" "$process_num"
wait_for_pod_creation
duration=$SECONDS
echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed." >>$outputfile
see_if_error $outputfile
pods_per_node
echo "Finished pod density" >>$outputfile
cat $outputfile
