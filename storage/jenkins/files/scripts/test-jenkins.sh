#!/bin/bash

readonly NAMESPACE=${1}
readonly ITERATION=${2}
readonly TMP_FOLDER=${3}

output_dir=$4
readonly TEST_BUILD_NUMBER=${5}
### start from 0
readonly TOTAL_BUILD_NUMBER=29

echo "NAMESPACE: ${NAMESPACE}"
echo "ITERATION: ${ITERATION}"
echo "TMP_FOLDER: ${TMP_FOLDER}"
echo "output_dir: ${output_dir}"
echo "TEST_BUILD_NUMBER: ${TEST_BUILD_NUMBER}"

readonly JJB_POD=$(oc get pod -n ${NAMESPACE} | grep jjb | awk '{print $1}')
readonly JENKINS_URL=$(oc get route -n ${NAMESPACE} --no-headers | awk '{print $2}')

oc exec -n ${NAMESPACE} "${JJB_POD}" -- rm -f /data/*
oc rsync -n ${NAMESPACE} "${TMP_FOLDER}/files/svt_jobs/" "${JJB_POD}:/data"

### Install tools
curl -s -k --user admin:password --data-urlencode "script=$(cat ${TMP_FOLDER}/files/groovy/install_mvn339.groovy)" -X POST "https://${JENKINS_URL}/scriptText"
curl -s -k --user admin:password --data-urlencode "script=$(cat ${TMP_FOLDER}/files/groovy/install_jdk8.groovy)" -X POST "https://${JENKINS_URL}/scriptText"
curl -s -k --user admin:password --data-urlencode "script=$(cat ${TMP_FOLDER}/files/groovy/jenkins_setup_jdk_user.groovy)" -X POST "https://${JENKINS_URL}/scriptText"

sleep 10

function trigger()
{
  local url
  url=$1
  local job_name
  job_name=$2
  curl -s -k --user admin:password -X POST "https://${url}/job/${job_name}/build" --data-urlencode json='{"parameter": []}'
}


function check_build() {
  local interval
  interval=$1
  local timeout
  timeout=$2
  local start_time
  start_time=$(date +%s)
  local result
  local all_success
  local j
  j=0
  while (( ($(date +%s) - ${start_time}) < ${timeout} ));
  do
    all_success=1
    for i in $(seq ${j} ${TEST_BUILD_NUMBER})
      do
        j=${i}
        ### it is not that straightforward to parse json without jq here
        result=$(curl -s -k --user admin:password https://${JENKINS_URL}/job/test-${i}_job/job/ttt/1/api/json | jq '.result' --raw-output)
        echo "${NAMESPACE}: job ${i}: ${result}"
        if [[ "${result}" != "SUCCESS" ]]; then
          all_success=0
          if [[ "${result}" = "FAILURE" ]] || [[ "${result}" = "UNSTABLE" ]] || [[ "${result}" = "ABORTED" ]]; then
            NON_SUCCESS_JOB_NUMBER=$((NON_SUCCESS_JOB_NUMBER+1))
            continue
          elif [[ "${result}" != "null" ]]; then
            echo "unknown build results: ${NAMESPACE}: job ${i}: ${result}"
          fi
          break
        fi
    done
    if (( ${j} == ${TEST_BUILD_NUMBER} )) && ([[ "${result}" = "FAILURE" ]] || [[ "${result}" = "UNSTABLE" ]] || [[ "${result}" = "ABORTED" ]]);
    then
      MY_TIME=$(($(date +%s) - ${start_time}))
      echo "the last job ${j} is FAILURE or UNSTABLE, exiting ..."
      break
    fi
    if (( ${all_success} == 1 ));
    then
      MY_TIME=$(($(date +%s) - ${start_time}))
      break
    fi
    sleep ${interval}
  done
}


readonly TIMEOUT=1800

for i_index in $(seq 1 ${ITERATION});
do
  echo "${NAMESPACE} iteration: ${i_index}"
  ### delete jobs
  for j in $(seq 0 ${TOTAL_BUILD_NUMBER}); do oc exec -n ${NAMESPACE} "${JJB_POD}" -- jenkins-jobs  delete test-${j}_job; done
  sleep 10
  ### create jobs
  oc exec -n ${NAMESPACE} "${JJB_POD}" -- jenkins-jobs --flush-cache  update --delete-old /data
  ### trigger jobs
  for j in $(seq 0 ${TEST_BUILD_NUMBER}); do trigger "${JENKINS_URL}" "test-${j}_job"; done
  sleep 10
  MY_TIME=-1
  NON_SUCCESS_JOB_NUMBER=0
  ### check jobs
  check_build 10 ${TIMEOUT}
  msg="${NAMESPACE} and iteration ${i_index}: All builds finished in ${MY_TIME} seconds and NON_SUCCESS_JOB_NUMBER is ${NON_SUCCESS_JOB_NUMBER}"
  if (( ${MY_TIME} == -1 )); then
    msg="not finished in ${TIMEOUT} seconds for ${NAMESPACE} and iteration ${i_index}"
  fi
  echo "${msg}"
  echo "${msg}" > ${output_dir}/jenkins_result_run_${NAMESPACE}_${i_index}_brief.txt
  echo "${MY_TIME}" >> ${output_dir}/jenkins_result_${NAMESPACE}_numbers.txt
done




