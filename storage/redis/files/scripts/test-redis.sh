#!/bin/bash

set -e

readonly NAMESPACE=${1}
readonly ITERATION=${2}
readonly THREADS=${3}
readonly WORKLOAD=${4}

output_dir=$5

readonly REDIS_IP=$(oc get svc -n ${NAMESPACE} | grep -v glusterfs | grep redis | awk '{print $3}')
readonly REDIS_POD=$(oc get pod -n ${NAMESPACE} | grep redis | awk '{print $1}')
readonly YCSB_POD=$(oc get pod -n ${NAMESPACE} | grep ycsb | awk '{print $1}')

if [[ ! -z "${benchmark_results_dir}" ]]; then
  output_dir="${benchmark_results_dir}"
fi

echo "NAMESPACE: ${NAMESPACE}"
echo "ITERATION: ${ITERATION}"
echo "THREADS: ${THREADS}"
echo "WORKLOADS: ${WORKLOAD}"


for i in $(seq 1 ${ITERATION}); do
  for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do
	for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do
	  echo "ITERATION: ${i}; WORKLOAD: ${load}; THREADS: ${thread}"
      oc -n ${NAMESPACE} exec "${REDIS_POD}" -- scl enable rh-redis32 -- redis-cli -a redhat FLUSHDB
	  oc -n ${NAMESPACE} exec "${YCSB_POD}" -- ./bin/ycsb load redis -s -threads ${thread} -P "workloads/${load}" -p "redis.host=${REDIS_IP}" -p "redis.port=6379" -p "redis.password=redhat" 2>&1 | tee -a ${output_dir}/redis_load_data_${NAMESPACE}_iter_${i}_${load}_threads_${thread}.txt
      oc -n ${NAMESPACE} exec "${YCSB_POD}" -- ./bin/ycsb run redis -s -threads ${thread} -P "workloads/${load}" -p "redis.host=${REDIS_IP}" -p "redis.port=6379" -p "redis.password=redhat" 2>&1 | tee -a ${output_dir}/redis_run_load_${NAMESPACE}_iter_${i}_${load}_threads_${thread}.txt
	done
  done
done




