#!/bin/bash

readonly NAMESPACE_BASENAME=${1}
readonly ITERATION=${2}
readonly TMP_FOLDER=${3}
readonly DELETE_EXISTING_PROJECTS=$(echo "$4" | awk '{print tolower($0)}')

echo "NAMESPACE_BASENAME: ${NAMESPACE_BASENAME}"
echo "ITERATION: ${ITERATION}"
echo "TMP_FOLDER: ${TMP_FOLDER}"
echo "DELETE_EXISTING_PROJECTS: ${DELETE_EXISTING_PROJECTS}"

readonly MEMORY_LIMIT=$5
readonly VOLUME_CAPACITY=$6
readonly STORAGE_CLASS_NAME=$7
readonly JENKINS_IMAGE_STREAM_TAG=$8
readonly JJB_STORAGE_CLASS_NAME=$9

function wait_until_the_project_is_gone {
  local project
  project=$1
  local timeout
  timeout=$2
  local interval
  interval=$3

  local start_time
  start_time=$(date +%s)

  local code
  while (( ($(date +%s) - ${start_time}) < ${timeout} ));
  do
    oc get project ${project} 2>&1 | grep "not found"
    code=$?
    if [[ ${code} -ne 0 ]]; then
      echo "the project is still there"
      sleep ${interval}
    else
      echo "the project is gone"
      MY_TIME=$(($(date +%s) - ${start_time}))
      break
    fi
  done
}

function wait_until_the_pod_is_ready {
  local project
  project=$1
  local pod
  pod=$2
  local timeout
  timeout=$3
  local interval
  interval=$4

  local start_time
  start_time=$(date +%s)

  local ready_pods
  while (( ($(date +%s) - ${start_time}) < ${timeout} ));
  do
    ready_pods=$(oc get pod -n ${project} | grep ${pod} | grep -v deploy | grep Running | grep 1/1 | wc -l)
    if [[ "${ready_pods}" == "1" ]]; then
      MY_TIME=$(($(date +%s) - ${start_time}))
      break
    fi
    echo "pod ${pod} is not ready yet ... waiting"
    sleep ${interval}
  done
}

for i in $(seq 1 ${ITERATION});
do
  echo "delete ${i}..."
  NAMESPACE="${NAMESPACE_BASENAME}-${i}"
  if [[ "${DELETE_EXISTING_PROJECTS}" == "true" ]];
  then
    oc delete project ${NAMESPACE}
  fi
done

for i in $(seq 1 ${ITERATION});
do
  echo "create ${i}..."
  NAMESPACE="${NAMESPACE_BASENAME}-${i}"
  if [[ "${DELETE_EXISTING_PROJECTS}" == "true" ]];
  then
    MY_TIME=-1
    wait_until_the_project_is_gone ${NAMESPACE} 180 10
    if (( ${MY_TIME} == -1 )); then
      echo "project ${NAMESPACE} is still there, time is up"
      exit 1
    else
      echo "it took ${MY_TIME} seconds to delete the project ${NAMESPACE}"
    fi
  fi
  oc new-project ${NAMESPACE} --skip-config-write=true
  oc process -f "${TMP_FOLDER}/files/oc/jenkins-persistent-template.yaml" \
      -p ENABLE_OAUTH=false -p MEMORY_LIMIT=${MEMORY_LIMIT} \
      -p VOLUME_CAPACITY=${VOLUME_CAPACITY} \
      -p STORAGE_CLASS_NAME=${STORAGE_CLASS_NAME} \
      -p JENKINS_IMAGE_STREAM_TAG=${JENKINS_IMAGE_STREAM_TAG} \
      | oc create --namespace=${NAMESPACE} -f -

  oc process -f ${TMP_FOLDER}/files/oc/pvc_template.yaml \
      -p PVC_NAME=jjb-pvc -p STORAGE_CLASS_NAME=${JJB_STORAGE_CLASS_NAME} \
      | oc create -n "${NAMESPACE}" -f -
  oc process -f ${TMP_FOLDER}/files/oc/cm_jjb_template.yaml \
      -p "JENKINS_URL=https://$(oc get route -n ${NAMESPACE} --no-headers | awk '{print $2}')" \
      | oc create -n "${NAMESPACE}" -f -
  oc create -n "${NAMESPACE}" -f ${TMP_FOLDER}/files/oc/dc_jjb.yaml
done


for i in $(seq 1 ${ITERATION});
do
  echo "wait ${i}..."
  NAMESPACE="${NAMESPACE_BASENAME}-${i}"
  MY_TIME=-1
  wait_until_the_pod_is_ready ${NAMESPACE} jenkins 180 10
  if (( ${MY_TIME} == -1 )); then
    echo "jenkins pod is not ready, time is up"
    exit 1
  else
    echo "it took ${MY_TIME} seconds to get jenkins pod ready"
  fi
  MY_TIME=-1
  wait_until_the_pod_is_ready ${NAMESPACE} jjb 180 10
  if (( ${MY_TIME} == -1 )); then
    echo "jjb pod is not ready, time is up"
    exit 1
  else
    echo "it took ${MY_TIME} seconds to get jjb pod ready"
  fi
done
