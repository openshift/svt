#!/bin/bash
source common.sh
while getopts p:t:n:r: FLAG
do
    case "${FLAG}" in
        p) PROJECT_NAME=${OPTARG};;
        t) WORKLOAD_TYPE=${OPTARG};;
        n) WORKLOAD_NAME=${OPTARG};;
        r) MAX_RETRY=${OPTARG};;
	*) echo "Invalid parameter, unsupported option ${FLAG}"
           exit 1;;
    esac
done

if [ $# -ne 8 ];then
     echo "Please input correct parameter"
     echo -e "$0:\n -p project name\n -t workload type: statefulset/deployment\n -n workload name\n -r retry times"
else
     create_project ${PROJECT_NAME} 
     wait_workload_ready  ${PROJECT_NAME} ${WORKLOAD_TYPE} ${WORKLOAD_NAME} ${MAX_RETRY}
fi
