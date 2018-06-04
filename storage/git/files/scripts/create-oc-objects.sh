#!/bin/bash

readonly NAMESPACE_BASENAME=${1}
readonly ITERATION=${2}
readonly TMP_FOLDER=${3}
readonly DELETE_EXISTING_PROJECTS=$(echo "$4" | awk '{print tolower($0)}')

echo "NAMESPACE_BASENAME: ${NAMESPACE_BASENAME}"
echo "ITERATION: ${ITERATION}"
echo "TMP_FOLDER: ${TMP_FOLDER}"
echo "DELETE_EXISTING_PROJECTS: ${DELETE_EXISTING_PROJECTS}"

readonly VOLUME_CAPACITY=$5
readonly STORAGE_CLASS_NAME=$6

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
  oc process -f "${TMP_FOLDER}/files/oc/template_git.yaml" \
      -p PVC_SIZE=${VOLUME_CAPACITY} \
      -p STORAGE_CLASS_NAME=${STORAGE_CLASS_NAME} \
      | oc create --namespace=${NAMESPACE} -f -
done


for i in $(seq 1 ${ITERATION});
do
  echo "wait ${i}..."
  NAMESPACE="${NAMESPACE_BASENAME}-${i}"
  MY_TIME=-1
  wait_until_the_pod_is_ready ${NAMESPACE} git 180 10
  if (( ${MY_TIME} == -1 )); then
    echo "git pod is not ready, time is up"
    exit 1
  else
    echo "it took ${MY_TIME} seconds to get git pod ready"
  fi
done
