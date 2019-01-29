#!/bin/bash

set -e

readonly NAMESPACE=${1}
readonly ITERATION=${2}
readonly THREADS=${3}
readonly WORKLOAD=${4}
readonly RECORDCOUNT=${5}
readonly OPERATIONCOUNT=${6}
readonly DISTRIBUTION=${7}



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
echo "DISTRIBUTION: ${DISTRIBUTION}" 

mkdir -p ${output_dir}/load_data
mkdir -p ${output_dir}/mongodb_data_size
mkdir -p ${output_dir}/mongodb_run_test 
mkdir -p ${output_dir}/mongodb_data_size_before_test
mkdir -p ${output_dir}/mongodb_pods_logs
# load phase 

for i in $(seq 1 ${ITERATION}); do 
	ADMIN_PASS=$(oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep mongodb | awk '{print $1}') -- scl enable rh-mongodb32 -- env | grep MONGODB_ADMIN_PASSWORD | cut -d'=' -f2)
	oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep mongodb | awk '{print $1}') -- scl enable rh-mongodb32 -- mongo testdb -p "${ADMIN_PASS}" -u admin --authenticationDatabase "admin" --eval "db.dropDatabase()" 
	echo "database dropped.... sleep 10s"
	sleep 10 
	for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do 
		for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do 
			
			# get data size prior load step 
			# todo - fix case when loads are as workloada,workloadb ... 
			oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep mongodb | awk '{print $1}') -- scl enable rh-mongodb32 -- mongo --eval  "db.stats(1024*1024*1024)" 127.0.0.1:27017/testdb -p redhat -u redhat > ${output_dir}/mongodb_data_size_before_test/mongodb_data_size_${load}_${NAMESPACE}.txt

			oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep ycsb | awk '{print $1}') -- ./bin/ycsb load mongodb -s -threads $thread -P "workloads/${load}" -p mongodb.url=mongodb://redhat:redhat@${MONGODB_IP}:27017/testdb -p recordcount=${RECORDCOUNT} -p operationcount=${OPERATIONCOUNT} -p requestdistribution=${DISTRIBUTION} -p mongodb.writeConcern=acknowledged -p wtimeout=10000 -p core_workload_insertion_retry_limit=5 -p core_workload_insertion_retry_interval=5 -p maxexecutiontime=28800 2>&1 | tee -a ${output_dir}/load_data/mongodb_load_data_${NAMESPACE}_${load}_threads_${thread}.txt

		# get db size after load step 
			oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep mongodb | awk '{print $1}') -- scl enable rh-mongodb32 -- mongo --eval  "db.stats(1024*1024*1024)" 127.0.0.1:27017/testdb -p redhat -u redhat > ${output_dir}/mongodb_data_size/mongodb_data_size_${load}_${NAMESPACE}.txt
		done 
   	done 
done

# sort result 

for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do
	for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do

		echo "Throughput" > ${output_dir}/result_${load}_threads_${thread}.csv
		grep "Throughput" ${output_dir}/load_data/mongodb_*  | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_threads_${thread}.csv 

	        
                # insert 
		echo "INSERT-95thPercentileLatency" > ${output_dir}/result_${load}_insert95lat_${thread}.csv 
		grep "\[INSERT\]\, 95thPercentileLatency" ${output_dir}/load_data/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_insert95lat_${thread}.csv
		
		echo "INSERT-99thPercentileLatency" > ${output_dir}/result_${load}_insert99lat_${thread}.csv
		grep "\[INSERT\]\, 99thPercentileLatency" ${output_dir}/load_data/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_insert99lat_${thread}.csv
		
		echo "Runtime(ms)" > ${output_dir}/result_runtime_${load}_thread_${thread}.csv
		grep "RunTime" ${output_dir}/load_data/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_runtime_${load}_thread_${thread}.csv

	done
done 

for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do
	for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do
		paste -d',' ${output_dir}/result_${load}_threads_${thread}.csv \
			${output_dir}/result_runtime_${load}_thread_${thread}.csv \
			${output_dir}/result_${load}_insert95lat_${thread}.csv \
			${output_dir}/result_${load}_insert99lat_${thread}.csv  > ${output_dir}/Throughput_Load_lat_${load}_threads_${thread}.csv 
	done 
done 
