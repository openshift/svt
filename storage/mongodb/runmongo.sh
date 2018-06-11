#!/bin/bash 

MEMORY_LIMIT="${1}"
ycsb_threads="${2}"
JUMP_HOST="${3}"
WORKLOAD="${4}"
ITERATIONS="${5}"
RECORDCOUNT="${6}"
OPERATIONCOUNT="${7}"
STORAGECLASS="${8}"
VOLUMECAPACITY="${9}"


for memory_limit in $(echo ${MEMORY_LIMIT} | sed -e s/,/" "/g); do
	ansible-playbook -i "${JUMP_HOST}," mongodb-test.yaml --extra-vars "MEMORY_LIMIT=${memory_limit}Mi ycsb_threads=${ycsb_threads} workload=${WORKLOAD} iteration=${ITERATIONS} \
	recordcount=${RECORDCOUNT} operationcount=${OPERATIONCOUNT} STORAGE_CLASS_NAME=${STORAGECLASS} VOLUME_CAPACITY=${VOLUMECAPACITY}Gi" 
done 
