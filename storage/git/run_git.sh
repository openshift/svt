
#!/bin/bash

JUMP_HOST="${1}"
ITERATIONS="${2}"
test_project_name="${3}"
test_project_number="${4}"
STORAGE_CLASS_NAMES="${5}"
pbench_registration="${6}"
pbench_copy_result="${7}"
benchmark_timeout="${8}"

for sc in $(echo ${STORAGE_CLASS_NAMES} | sed -e s/,/" "/g); do
  echo "===search-me: sc: ${sc}"
  ansible-playbook -i "${JUMP_HOST}," git-test.yaml \
  --extra-vars "test_project_name=${test_project_name} STORAGE_CLASS_NAME=${sc} iteration=${ITERATIONS} test_project_number=${test_project_number} pbench_registration=${pbench_registration} pbench_copy_result=${pbench_copy_result} benchmark_timeout=${benchmark_timeout} jump_node=true"
done