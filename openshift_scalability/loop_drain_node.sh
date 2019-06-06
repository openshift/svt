#!/bin/bash

### Original file: https://github.com/skordas/svt-case-doc/blob/master/scripts/loop_drain_node.sh
### Eg of the command: bash aaa.sh ip-172-31-35-104.us-west-2.compute.internal ip-172-31-49-226.us-west-2.compute.internal 25 50
### # oc get node
### NAME                                          STATUS                     ROLES     AGE       VERSION
### ...
### ip-172-31-35-104.us-west-2.compute.internal   Ready                      compute   10h       v1.11.0+d4cacc0
### ip-172-31-49-226.us-west-2.compute.internal   Ready,SchedulingDisabled   compute   10h       v1.11.0+d4cacc0
### 25: the number of fio pods which are running
### 50: number of iterations

if [ "$#" -ne 4 ]; then
    echo "Illegal number of parameters!"
    exit 1
fi

readonly NODE_1=$1
readonly NODE_2=$2
readonly POD_NUMBER=$3
readonly ITERATION=$4

echo "NODE_1: ${NODE_1}"
echo "NODE_2: ${NODE_2}"
echo "POD_NUMBER: ${POD_NUMBER}"
echo "ITERATION: ${ITERATION}"


function wait_until_all_pods_are_ready {
  local total
  total=$1
  local pod
  pod=$2
  local timeout
  timeout=$3
  local interval
  interval=$4

  local start_time
  start_time=$(date +%s)

  local ready_pods
  while (( ($(date +%s) - ${start_time}) < ${timeout} ));
  do
    ready_pods=$(oc get pod --all-namespaces | grep ${pod} | grep -v deploy | grep Running | grep 1/1 | wc -l)
    echo "running pods: ${ready_pods}"
    if [[ "${ready_pods}" == ${total} ]]; then
      MY_TIME=$(($(date +%s) - ${start_time}))
      break
    fi
    echo "some ${pod} pod is not ready yet ... waiting"
    sleep ${interval}
  done
}

readonly COMPUTE_NODE_NUMBER=$(oc get node -l aaa=bbb | awk '{print $3}' | grep worker | wc -l)
if [[ "${COMPUTE_NODE_NUMBER}" -ne "2" ]]; then
  echo "not 2 worker nodes, exiting ..."
  exit 1
fi

if [[ "$(oc get node ${NODE_1} | grep SchedulingDisabled | wc -l)" -ne "0" ]]; then
  echo "node ${NODE_1} is SchedulingDisabled, exiting ..."
  exit 1
fi

if [[ "$(oc get node ${NODE_2} | grep SchedulingDisabled | wc -l)" -ne "1" ]]; then
  echo "node ${NODE_2} is not SchedulingDisabled, exiting ..."
  exit 1
fi


for i in $(seq 1 ${ITERATION});
do
  echo "iteration: $i"
  oc adm uncordon ${NODE_2}
  echo "draining node1: ${NODE_1}"
  oc adm drain ${NODE_1} --ignore-daemonsets --pod-selector='test=fio'
  MY_TIME=-1
  wait_until_all_pods_are_ready ${POD_NUMBER} fio 1200 10
  if (( ${MY_TIME} == -1 )); then
    echo "fio pod is not ready, time is up"
    exit 1
  else
    echo "it took ${MY_TIME} seconds to get fio pod ready"
  fi
  echo "lsblk on node1 ..."
  oc debug node/${NODE_1} -- chroot /host lsblk
  echo "lsblk on node2 ..."
  oc debug node/${NODE_2} -- chroot /host lsblk
  echo "flipping ..."
  oc adm uncordon ${NODE_1}
  echo "draining node1: ${NODE_2}"
  oc adm drain ${NODE_2} --ignore-daemonsets --pod-selector='test=fio'
  MY_TIME=-1
  wait_until_all_pods_are_ready ${POD_NUMBER} fio 1200 10
  if (( ${MY_TIME} == -1 )); then
    echo "fio pod is not ready, time is up"
    exit 1
  else
    echo "it took ${MY_TIME} seconds to get fio pod ready"
  fi
  echo "lsblk on node1 ..."
  oc debug node/${NODE_1} -- chroot /host lsblk
  echo "lsblk on node2 ..."
  oc debug node/${NODE_2} -- chroot /host lsblk
done
