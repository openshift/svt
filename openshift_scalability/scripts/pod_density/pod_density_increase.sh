#/!/bin/bash
################################################
## Auth=prubenda@redhat.com
## Desription: Script for running pod density of different number of projects
################################################

outputfile=pod_density.out
proj_yaml="test.yaml"

function deployments_running(){
  oc get pods -A | grep svt | egrep -v 1-deploy
}


function deployments_running(){
  running_deploys=$(oc get pods -A | grep svt | grep 1-deploy | grep Running | wc -l)
  while [ $running_deploys -ne 0 ]; do
    sleep 5
    running_deploys=$(oc get pods -A | grep svt | grep 1-deploy | grep Running | wc -l)
    echo "Some deploy pods are still running"
  done

}

function create_projects() {

  COUNTER=$1
  while [ $COUNTER -le $3 ]; do
    python -c "import increase_pods; increase_pods.print_new_yaml($COUNTER,'$proj_yaml')"
    echo "running project count $COUNTER"
    ./pod_density.sh $proj_yaml -s $scale_num -cp $cluster_processes -p $project_num
    deployments_running
    error=$(oc get pods --all-namespaces | grep svt | grep Error | wc -l)
    echo "error pods $error"
    sleep 10
    COUNTER=$((COUNTER + $2))
    if [ $error -ne 0 ]; then
      echo error
      break
    fi
  done
}

max_num=2000
start_num=200
increase_counter=20
process_num=5
scale_num=20
project_num=2000
#optional parameters
while [[ $# -gt 1 ]]
do
key="$1"
echo "key $key"

case $key in
    -s|--start_num)
    start_num=$2
    echo "start $start_num"
    shift # past argument
    shift # past value
    ;;
    -i|--increase_counter)
    increase_counter=$2
    echo "increase_counter $increase_counter"
    shift # past argument
    shift # past value
    ;;
    -m|--max_pods)
    max_num=$2
    echo "max_num $max_num"
    shift # past argument
    shift # past value
    ;;
    -f|--file_name)
    proj_yaml=$2
    shift
    shift
    ;;
    -sc|--scale_num)
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

echo "params $start_num $increase_counter $max_num"
create_projects $start_num $increase_counter $max_num
