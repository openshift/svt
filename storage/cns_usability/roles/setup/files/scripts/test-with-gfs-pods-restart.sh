#!/bin/bash

set -e

readonly TIMEOUT=1800

readonly NAMESPACE=${1}


readonly FIO_POD=$(oc get pod -n ${NAMESPACE} | grep fio | awk '{print $1}')

line_number=$(oc exec -n ${NAMESPACE} ${FIO_POD} -- tail -n 1 /mnt/pvcmount/test.log | awk '{print $10}')


if (( ${line_number} > 100000 )); then
  echo "line number is ${line_number}, over 1000, too late for starting"
  exit 1
fi

echo "starting: line number is ${line_number}"

function wait_until_all_gfs_pods_ready() {
  local interval
  interval=$1
  local timeout
  timeout=$2
  local start_time
  start_time=$(date +%s)
  local ready_pods
  while (( ($(date +%s) - ${start_time}) < ${timeout} ));
  do
    ready_pods=$(oc get pod -n glusterfs | grep glusterfs-storage | grep -v Terminating | grep 1/1 | wc -l)
    if [[ "${ready_pods}" == "3" ]]; then
      MY_TIME=$(($(date +%s) - ${start_time}))
      break
    fi
    echo "only ${ready_pods} glusterfs pods are ready ... waiting"
    sleep ${interval}
  done
}

MY_TIME=-1
wait_until_all_gfs_pods_ready 15 300
if (( ${MY_TIME} == -1 )); then
  echo "only ${ready_pods} glusterfs pods are ready, time is up"
  exit 1
else
  echo "it took ${MY_TIME} seconds to get all 3 gfs pods ready"
fi

oc get pod -n glusterfs | grep glusterfs-storage | awk '{print $1}' | while read line; do
  echo "deleting pod $line"
  oc delete pod -n glusterfs ${line}
  sleep 10
  MY_TIME=-1
  wait_until_all_gfs_pods_ready 15 300
  if (( ${MY_TIME} == -1 )); then
    echo "only ${ready_pods} glusterfs pods are ready, time is up"
    exit 1
  else
    echo "it took ${MY_TIME} seconds to get the killed gfs pod ready"
  fi
done

line_number=$(oc exec -n ${NAMESPACE} ${FIO_POD} -- tail -n 1 /mnt/pvcmount/test.log | awk '{print $10}')
if (( ${line_number} > 850000 )); then
  echo "line number is ${line_number}, over 280000, too late for finishing"
  exit 1
fi
echo "finishing: line number is ${line_number}"