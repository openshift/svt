#!/bin/bash

set -e

readonly NAMESPACE_BASENAME=${1}
readonly NAMESPACE_NUMBER=${2}
readonly ITERATION=${3}
readonly THREADS=${4}
readonly WORKLOAD=${5}

scripts_dir=$(dirname $0)
output_dir=${6}

echo "NAMESPACE_BASENAME: ${NAMESPACE_BASENAME}"
echo "NAMESPACE_NUMBER: ${NAMESPACE_NUMBER}"
echo "ITERATION: ${ITERATION}"
echo "THREADS: ${THREADS}"
echo "WORKLOADS: ${WORKLOAD}"

for i in $(seq 1 ${NAMESPACE_NUMBER});
do
  NAMESPACE="${NAMESPACE_BASENAME}-${i}"
  echo "NAMESPACE is ${NAMESPACE}"
  "${scripts_dir}/test-redis.sh" "${NAMESPACE}" "${ITERATION}" "${THREADS}" "${WORKLOAD}" "${output_dir}" &
done

wait
