#!/bin/bash

set -e

readonly NAMESPACE=${1}
readonly ITERATION=${2}
readonly TMP_FOLDER=${3}

output_dir=$4

readonly GIT_URL=https://github.com/eclipse/che.git
readonly WORK_GIT_DIR=/data/repo

echo "NAMESPACE: ${NAMESPACE}"
echo "ITERATION: ${ITERATION}"
echo "TMP_FOLDER: ${TMP_FOLDER}"
echo "output_dir: ${output_dir}"

readonly GIT_POD=$(oc get pod -n ${NAMESPACE} | grep -v deploy | grep git | awk '{print $1}')

for i_index in $(seq 1 ${ITERATION});
do
  ### git clone
  echo "${NAMESPACE} iteration: ${i_index}"
  MY_TIME=-1
  start_time=$(date +%s)
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- rm -rf "${WORK_GIT_DIR}"
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- mkdir -p "${WORK_GIT_DIR}"
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- git -C "${WORK_GIT_DIR}" clone "${GIT_URL}"
  echo "git status ..."
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- git -C "${WORK_GIT_DIR}/che" status
  ### tar & untar
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- rm -rf "${WORK_GIT_DIR}/untar"
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- mkdir -p "${WORK_GIT_DIR}/untar"
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- tar -zcf "${WORK_GIT_DIR}/che.tar.gz" "${WORK_GIT_DIR}/che"
  echo "ls che.tar.gz ..."
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- ls -al "${WORK_GIT_DIR}/che.tar.gz"
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- tar -zxf "${WORK_GIT_DIR}/che.tar.gz" -C "${WORK_GIT_DIR}/untar"
  echo "du untar folder ..."
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- du -sh "${WORK_GIT_DIR}/untar"
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- rm -rf "${WORK_GIT_DIR}/untar"
  MY_TIME=$(($(date +%s) - ${start_time}))
  echo "${NAMESPACE} iteration: ${i_index}: finished in ${MY_TIME} secs"
done



