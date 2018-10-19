#!/bin/bash

set -e

echo "001 $(date)"

if [[ "$#" -ne 2 ]]; then
    echo "need need the path of tmp folder and PROJECT"
    exit 1
fi

readonly TMP_FOLDER=$1
readonly PROJECT=$2

readonly STORAGE_CLASS_NAME=$(oc get pvc -n ${PROJECT} --no-headers | awk '{print $6}')
readonly POD=$(oc get pod -n ${PROJECT} -o wide --no-headers | awk '{print $1}')
readonly POD_IP=$(oc get pod -n ${PROJECT} -o wide --no-headers | awk '{print $6}')

echo "STORAGE_CLASS_NAME: ${STORAGE_CLASS_NAME}"
echo "POD: ${POD}"
echo "POD_IP: ${POD_IP}"

readonly SCRIPTS_FOLDER=/scripts

oc exec -n ${PROJECT} ${POD} -- rm -rfv "${SCRIPTS_FOLDER}"
oc exec -n ${PROJECT} ${POD} -- mkdir "${SCRIPTS_FOLDER}"
oc rsync -n "${PROJECT}" "${TMP_FOLDER}/files/scripts/" "${POD}:${SCRIPTS_FOLDER}"

pbench-user-benchmark --config="fio_test_${STORAGE_CLASS_NAME}" -- oc exec -n "${PROJECT}" "${POD}" -- bash "${SCRIPTS_FOLDER}/fio.sh"

echo "002 $(date)"


