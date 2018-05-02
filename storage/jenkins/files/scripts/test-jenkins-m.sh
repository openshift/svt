#!/bin/bash

set -e

readonly NAMESPACE_BASENAME=${1}
readonly NAMESPACE_NUMBER=${2}
readonly ITERATION=${3}
readonly TMP_FOLDER=${4}
readonly TEST_BUILD_NUMBER=${5}

scripts_dir=$(dirname $0)
output_dir=${scripts_dir}

if [[ ! -z "${benchmark_results_dir}" ]]; then
  output_dir="${benchmark_results_dir}"
fi

echo "NAMESPACE_BASENAME: ${NAMESPACE_BASENAME}"
echo "NAMESPACE_NUMBER: ${NAMESPACE_NUMBER}"
echo "ITERATION: ${ITERATION}"
echo "TMP_FOLDER: ${TMP_FOLDER}"

for i in $(seq 1 ${NAMESPACE_NUMBER});
do
  NAMESPACE="${NAMESPACE_BASENAME}-${i}"
  echo "NAMESPACE is ${NAMESPACE}"
  "${scripts_dir}/test-jenkins.sh" "${NAMESPACE}" "${ITERATION}" "${TMP_FOLDER}" "${output_dir}" "${TEST_BUILD_NUMBER}" &
done

wait
