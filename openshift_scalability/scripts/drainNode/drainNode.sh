#!/bin/bash

proj_yaml="../../content/fio/fio-parameters-drain-node.yaml"

pod_array=(1 2 5 10 25)
iterations=25
final_log='drain_times.out'
rm $final_log

#set node1 and 2
worker_nodes=$(oc get nodes | grep worker)

function wait_for_project_termination() {
  COUNTER=0
  terminating=$(oc get projects | grep fio | grep Terminating | wc -l)
  while [ $terminating -ne 0 ]; do
    echo "$terminating projects are still terminating"
    sleep 3
    terminating=$(oc get projects | grep fio | grep Terminating | wc -l)
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 20 ]; then
      echo "$terminating projects are still terminating after a minute"
      exit 1
    fi
  done
}

function get_average_times() {
  grep "seconds to get fio pod ready" $1 >> $2
  echo "$2 $3 $4"
  python -c "from drain_helper import get_time_stats; get_time_stats('$2', '$3', $4)"

}

fio_projects=$(oc get projects | grep fio | wc -l)
if [ "$fio_projects" -gt 0 ]; then
  echo "ERROR: Fio project(s) already exist, please delete before rerunning"
  exit 1
fi

counter=0
for node in $worker_nodes
do
    if [ "$counter" -eq 0 ]; then
      node_1=$node
    fi
    if [ "$counter" -eq 1 ]; then
      if [ "$node" != "Ready" ]; then
        echo "Node $node_1 is not Ready and schedulable. Uncordon node before rerunning"
        exit 1
      fi
    fi
    if [ "$counter" -eq 5 ]; then
      node_2=$node
    fi
    if [ "$counter" -eq 6 ]; then
      if [ "$node" != "Ready" ]; then
        echo "Node $node_2 is not Ready and schedulable. Uncordon node before rerunning"
        exit 1
      fi
    fi
    if [ "$counter" -eq 10 ]; then
      echo "ERROR: Can only have 2 worker nodes for this test"
      exit 1
    fi
    counter=$((counter + 1))
done

#Label nodes
oc label node ${node_1} aaa=bbb && oc label node ${node_2} aaa=bbb

#Make node_2 SchedulingDisabled
oc adm cordon ${node_2}

rmdir output
mkdir output

for pods_n in "${pod_array[@]}"
do
  pods_log="output/loop_$pods_n.log"
  pods_out="output/drain_times_$pods_n.out"
  rm $pods_log
  rm $pods_out
  python -c "from drain_helper import print_new_yaml_temp; print_new_yaml_temp($pods_n,'$proj_yaml')"
  echo "running project count $pods_n"
  python -u ../../cluster-loader.py -v -f $proj_yaml
  ./loop_drain_node.sh $node_1 $node_2 $pods_n $iterations | tee $pods_log
  get_average_times $pods_log $pods_out $final_log $pods_n
  oc delete project fiotest0
  wait_for_project_termination
done

# Uncordon both nodes for cleanup
# Need both if failure, either could be scheduling disabled
oc adm uncordon ${node_1}
oc adm uncordon ${node_2}

cat $final_log