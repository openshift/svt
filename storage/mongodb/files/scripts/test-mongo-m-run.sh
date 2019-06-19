#!/bin/bash

set -e

readonly NAMESPACE_BASENAME=${1}
readonly NAMESPACE_NUMBER=${2}
readonly ITERATION=${3}
readonly THREADS=${4}
readonly WORKLOAD=${5}
readonly RECORD_COUNT=${6}
readonly OPERATION_COUNT=${7}
readonly DISTRIBUTION=${8}

scripts_dir=$(dirname $0)
output_dir=${9}

echo "NAMESPACE_BASENAME: ${NAMESPACE_BASENAME}"
echo "NAMESPACE_NUMBER: ${NAMESPACE_NUMBER}"
echo "ITERATION: ${ITERATION}"
echo "THREADS: ${THREADS}"
echo "WORKLOADS: ${WORKLOAD}"
echo "DISTRIBUTION: ${DISTRIBUTION}"

echo "load done... running test" 

for i in $(seq 1 ${NAMESPACE_NUMBER});do 
        NAMESPACE="${NAMESPACE_BASENAME}-${i}"
	echo "Test run for NAMESPACE: ${NAMESPACE}"
	"${scripts_dir}/test-mongo-run.sh" "${NAMESPACE}" "${ITERATION}" "${THREADS}" "${WORKLOAD}" "${RECORD_COUNT}" "${OPERATION_COUNT}" "${DISTRIBUTION}" "${output_dir}" &
done 


wait
