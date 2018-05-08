#!/bin/bash

set -e

readonly NAMESPACE=${1}
readonly ITERATION=${2}
readonly THREADS=${3}
readonly WORKLOAD=${4}

output_dir=$(dirname $0)

readonly MONGODB_IP=$(oc get svc -n ${NAMESPACE} | grep -v glusterfs | grep mongodb | awk '{print $3}')

if [[ ! -z "${benchmark_results_dir}" ]]; then
  output_dir="${benchmark_results_dir}"
fi

echo "NAMESPACE: ${NAMESPACE}"
echo "ITERATION: ${ITERATION}"
echo "THREADS: ${THREADS}"
echo "WORKLOADS: ${WORKLOAD}"

for i in $(seq 1 ${ITERATION});
do
  for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g);
  do
    echo "iteration: ${i} "and" ${load}"
    ## TODO support to override other params
    oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep mongodb | awk '{print $1}') -- scl enable rh-mongodb32 -- mongo -u redhat -p redhat ${MONGODB_IP}:27017/testdb --eval "db.usertable.remove({})"
    oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep ycsb | awk '{print $1}') -- ./bin/ycsb load mongodb -s -threads "${THREADS}" -P "workloads/${load}" -p mongodb.url=mongodb://redhat:redhat@${MONGODB_IP}:27017/testdb > ${output_dir}/mongodb_${load}_result_run_${THREADS}_${i}.txt 2>&1
    grep -E 'RunTime|Throughput' ${output_dir}/mongodb_${load}_result_run_${THREADS}_${i}.txt > ${output_dir}/mongodb_${load}_result_run_${THREADS}_${i}_brief.txt
    grep Throughput ${output_dir}/mongodb_${load}_result_run_${THREADS}_${i}.txt | cut -d',' -f3 >> ${output_dir}/mongodb_${load}_result_run_${THREADS}_numbers.txt
  done
done

