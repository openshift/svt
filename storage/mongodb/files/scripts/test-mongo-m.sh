#!/bin/bash

set -e

readonly NAMESPACE_BASENAME=${1}
readonly NAMESPACE_NUMBER=${2}
readonly ITERATION=${3}
readonly THREADS=${4}
readonly WORKLOAD=${5}
readonly RECORD_COUNT=${6}
readonly OPERATION_COUNT=${7}

scripts_dir=$(dirname $0)
output_dir=${scripts_dir}

if [[ ! -z "${benchmark_results_dir}" ]]; then
  output_dir="${benchmark_results_dir}"
fi

echo "NAMESPACE_BASENAME: ${NAMESPACE_BASENAME}"
echo "NAMESPACE_NUMBER: ${NAMESPACE_NUMBER}"
echo "ITERATION: ${ITERATION}"
echo "THREADS: ${THREADS}"
echo "WORKLOADS: ${WORKLOAD}"

for i in $(seq 1 ${NAMESPACE_NUMBER});
do
  NAMESPACE="${NAMESPACE_BASENAME}-${i}"
  echo "NAMESPACE is ${NAMESPACE}"
  "${scripts_dir}/test-mongo.sh" "${NAMESPACE}" "${ITERATION}" "${THREADS}" "${WORKLOAD}" "${RECORD_COUNT}" "${OPERATION_COUNT}" "${output_dir}" &
done

wait