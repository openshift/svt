#!/bin/bash

set -e

readonly NAMESPACE=${1}
readonly ITERATION=${2}
readonly THREADS=${3}
readonly WORKLOAD=${4}
readonly RECORDCOUNT=${5}
readonly OPERATIONCOUNT=${6}

output_dir=$(dirname $0)

readonly MONGODB_IP=$(oc get svc -n ${NAMESPACE} | grep -v glusterfs | grep mongodb | awk '{print $3}')

if [[ ! -z "${benchmark_results_dir}" ]]; then
  output_dir="${benchmark_results_dir}"
fi

echo "NAMESPACE: ${NAMESPACE}"
echo "ITERATION: ${ITERATION}"
echo "THREADS: ${THREADS}"
echo "WORKLOADS: ${WORKLOAD}"
echo "RECORDCOUNT: ${RECORDCOUNT}"
echo "OPERATIONCOUNT: ${OPERATIONCOUNT}"


for i in $(seq 1 ${ITERATION}); do 
  for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do 
	for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do 
    		oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep mongodb | awk '{print $1}') -- scl enable rh-mongodb32 -- mongo -u redhat -p redhat ${MONGODB_IP}:27017/testdb --eval "db.usertable.remove({})"
		oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep ycsb | awk '{print $1}') -- ./bin/ycsb load mongodb -s -threads $thread -P "workloads/${load}" -p mongodb.url=mongodb://redhat:redhat@${MONGODB_IP}:27017/testdb -p recordcount=${RECORDCOUNT} -p operationcount=${OPERATIONCOUNT} 2>&1 | tee -a ${output_dir}/mongodb_load_data_${load}_threads_${thread}.txt

		oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep ycsb | awk '{print $1}') -- ./bin/ycsb run mongodb -s -threads $thread -P "workloads/${load}" -p mongodb.url=mongodb://redhat:redhat@${MONGODB_IP}:27017/testdb -p recordcount=${RECORDCOUNT} -p operationcount=${OPERATIONCOUNT}  2>&1 | tee -a ${output_dir}/mongodb_run_load_${load}_threads_${thread}.txt
	done 
   done 
done

# sort result 

for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do
	for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do
		echo "Threads-${thread}" > ${output_dir}/result_${load}_threads_${thread}.txt 
		grep Throughput ${output_dir}/mongodb_run_load_${load}_threads_${thread}.txt | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_threads_${thread}.txt
	done
	paste -d',' ${output_dir}/result_${load}_threads_* > ${output_dir}/result_${load}_recordcount_${RECORDCOUNT}_operationcount_${OPERATIONCOUNT}.csv
done 




# todo - draw results here ... 

