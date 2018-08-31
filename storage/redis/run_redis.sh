#!/bin/bash 

JUMP_HOST="${1}"
ITERATIONS="${2}"
test_project_name="${3}"
test_project_number="${4}"
STORAGE_CLASS_NAMES="${5}"
pbench_copy_result="${6}"
benchmark_timeout="${7}"
MEMORY_LIMIT="${8}"
ycsb_threads="${9}"
workload="${10}"
VOLUME_CAPACITY="${11}"


for sc in $(echo ${STORAGE_CLASS_NAMES} | sed -e s/,/" "/g); do
  echo "===search-me: sc: ${sc}"
  ansible-playbook -i "${JUMP_HOST}," redis-test.yaml --extra-vars "test_project_name=${test_project_name} test_project_number=${test_project_number} MEMORY_LIMIT=${MEMORY_LIMIT} ycsb_threads=${ycsb_threads} workload=${workload} iteration=${ITERATIONS} STORAGE_CLASS_NAME=${sc} VOLUME_CAPACITY=${VOLUME_CAPACITY} pbench_copy_result=${pbench_copy_result} benchmark_timeout=${benchmark_timeout}"
done 
