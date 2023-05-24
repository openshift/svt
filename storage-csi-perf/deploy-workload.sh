#!/bin/bash
source common.sh
while getopts p:t:n:v:r: FLAG
do
    case "${FLAG}" in
        p) PROJECT_NAME=${OPTARG};;
        t) WORKLOAD_TYPE=${OPTARG};;
        n) WORKLOAD_NAME=${OPTARG};;
        v) PVC_NAME=${OPTARG};;
        r) DEFAULT_REPLICAS=${OPTARG};;
	*) echo "Invalid parameter, unsupported option ${FLAG}"
           exit 1;;
    esac
done

if [ $# -ne 10 ];then
     echo "Please input correct parameter"
     echo -e "$0:\n -p project name\n -t workload type: statefulset/deployment\n -n workload name\n -v pvc name\n -r default replicas"
else
     create_project ${PROJECT_NAME}
     deploy_workload ${PROJECT_NAME} ${WORKLOAD_TYPE} ${WORKLOAD_NAME} ${PVC_NAME} ${DEFAULT_REPLICAS}
fi
