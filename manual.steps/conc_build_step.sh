#!/bin/bash

echo "test"

readonly MY_DATE="$(date '+%d%m%Y')"
readonly RESULT_FOLDER="/tmp/${MY_DATE}_conc_builds"
readonly RECORD_FOLDER="/tmp/${MY_DATE}_conc_builds_record"

mkdir -p "${RESULT_FOLDER}"
mkdir -p "${RECORD_FOLDER}"

while read line;
do
  proj=$(echo "${line}" | awk '{print $1}')
  app=$(echo "${line}" | awk '{print $2}')
  if [[ ${proj} == proj* ]]; then
    logs=$(oc logs -n "${proj}" "${app}-build")
    #echo "yyy ${logs}"
    record_file="${RECORD_FOLDER}/${proj}_${app}_record.out"
    if [[ -f "${record_file}" ]]; then
      echo "skip (already processed build) ${proj} ${app}"
      continue
    fi
    if [[ ${logs} == *"Cannot connect to the Docker daemon. Is the docker daemon running on this host"* ]]; then
      echo "WARNING: ${proj} ${app}: docker busy"
    elif [[ ${logs} == *"free data blocks which is less than minimum required 6083 free data blocks"* ]]; then
      echo "WARNING: ${proj} ${app}: docker no space"
    elif [[ ${logs} == *"Error: No such container"* ]]; then
      echo "WARNING: ${proj} ${app}: docker container is deleted"
    elif [[ -z "${logs// }" ]]; then
      echo "WARNING: ${proj} ${app}: empty oc log"
    else
      oc_log_file="${RESULT_FOLDER}/${proj}_${app}_oc_log.out"
      echo "ERROR: found unknown error~write to file ${RESULT_FOLDER}/${proj}_${app}_*.out"
      printf '%s' "${logs}" > "${oc_log_file}"
      oc describe pod -n "${proj}" "${app}-build" > "${RESULT_FOLDER}/${proj}_${app}_oc_describe_pod.out"
    fi
    touch ${record_file}

  else
    echo "skipped line: ${line}"
  fi
done << EOF
$(oc get builds --all-namespaces | grep -i fail)
EOF
