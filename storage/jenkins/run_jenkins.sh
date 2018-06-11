#!/bin/bash

MEMORY_LIMIT="${1}"
JUMP_HOST="${2}"
ITERATIONS="${3}"
test_project_name="${4}"
test_project_number="${5}"
STORAGE_CLASS_NAMES="${6}"
test_build_number="${7}"
pbench_registration="${8}"
pbench_copy_result="${9}"
benchmark_timeout="${10}"

for sc in $(echo ${STORAGE_CLASS_NAMES} | sed -e s/,/" "/g); do
  echo "===search-me: sc: ${sc}"
  ansible-playbook -i "${JUMP_HOST}," jenkins-test.yaml \
  --extra-vars "MEMORY_LIMIT=${MEMORY_LIMIT} test_project_name=${test_project_name} STORAGE_CLASS_NAME=${sc} iteration=${ITERATIONS} test_build_number=${test_build_number} test_project_number=${test_project_number} pbench_registration=${pbench_registration} pbench_copy_result=${pbench_copy_result} benchmark_timeout=${benchmark_timeout}"
done 