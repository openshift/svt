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
  OUTPUT_RESULT_FILE=${output_dir}/result_${NAMESPACE}_${i_index}.txt
  MY_TIME=-1
  start_time=$(date +%s)
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- rm -rf "${WORK_GIT_DIR}"
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- mkdir -p "${WORK_GIT_DIR}"
  clone_start_time=$(date +%s)
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- git -C "${WORK_GIT_DIR}" clone "${GIT_URL}"
  clone_time=$(($(date +%s) - ${clone_start_time}))
  echo "${NAMESPACE} iteration: ${i_index}: git-clone is done in ${clone_time} secs" | tee -a "${OUTPUT_RESULT_FILE}"
  echo "git status ..."
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- git -C "${WORK_GIT_DIR}/che" status
  ### tar & untar
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- rm -rf "${WORK_GIT_DIR}/untar"
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- mkdir -p "${WORK_GIT_DIR}/untar"
  tar_start_time=$(date +%s)
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- tar -zcf "${WORK_GIT_DIR}/che.tar.gz" "${WORK_GIT_DIR}/che"
  tar_time=$(($(date +%s) - ${tar_start_time}))
  echo "${NAMESPACE} iteration: ${i_index}: tar is done in ${tar_time} secs" | tee -a "${OUTPUT_RESULT_FILE}"
  echo "ls che.tar.gz ..."
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- ls -al "${WORK_GIT_DIR}/che.tar.gz"
  un_tar_start_time=$(date +%s)
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- tar -zxf "${WORK_GIT_DIR}/che.tar.gz" -C "${WORK_GIT_DIR}/untar"
  un_tar_time=$(($(date +%s) - ${un_tar_start_time}))
  echo "${NAMESPACE} iteration: ${i_index}: un_t(ar) is done in ${un_tar_time} secs" | tee -a "${OUTPUT_RESULT_FILE}"
  echo "du untar folder ..."
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- du -sh "${WORK_GIT_DIR}/untar"
  rm_start_time=$(date +%s)
  oc exec -n ${NAMESPACE} "${GIT_POD}" -- rm -rf "${WORK_GIT_DIR}/untar"
  rm_time=$(($(date +%s) - ${rm_start_time}))
  echo "${NAMESPACE} iteration: ${i_index}: rm is done in ${rm_time} secs" | tee -a "${OUTPUT_RESULT_FILE}"
  MY_TIME=$(($(date +%s) - ${start_time}))
  echo "${NAMESPACE} iteration: ${i_index}: finished in ${MY_TIME} secs" | tee -a "${OUTPUT_RESULT_FILE}"
done



