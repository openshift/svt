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
	for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do 
		for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do 
			
			# test run 
			oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep ycsb | awk '{print $1}') -- ./bin/ycsb run mongodb -s -threads $thread -P "workloads/${load}" -p mongodb.url=mongodb://redhat:redhat@${MONGODB_IP}:27017/testdb 2>&1 -p recordcount=${RECORDCOUNT} -p operationcount=${OPERATIONCOUNT} -p requestdistribution=${DISTRIBUTION} -p mongodb.writeConcern=acknowledged -p wtimeout=10000 -p writeallfields=true -p maxexecutiontime=18000 | tee -a ${output_dir}/mongodb_run_test/mongodb_run_load_${NAMESPACE}_${load}_threads_${thread}.csv	
			# -p mongodb.writeConcern=strict - tested 

			# test finished ... get logs for mongodb pod 
			oc -n ${NAMESPACE} logs $(oc get pod -n ${NAMESPACE} | grep mongodb | awk '{print $1}') > ${output_dir}/mongodb_pods_logs/mongodb_logs_${NAMESPACE}.csv 
		done 
   	done 
done

# sort result 

for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do
	for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do

		echo "Throughput" > ${output_dir}/result_${load}_threads_${thread}.csv
		grep "Throughput" ${output_dir}/mongodb_run_test/mongodb_*  | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_threads_${thread}.csv

	        
                # read 	
		echo "READ-95thPercLat" > ${output_dir}/result_${load}_read95lat_${thread}.csv 
		grep "\[READ\]\, 95thPercentileLatency" ${output_dir}/mongodb_run_test/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_read95lat_${thread}.csv

		
		echo "READ-99thPercLat" > ${output_dir}/result_${load}_read99lat_${thread}.csv      
		grep "\[READ\]\, 99thPercentileLatency" ${output_dir}/mongodb_run_test/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_read99lat_${thread}.csv

		# update 

		echo "UPDATE-95thPercLat" > ${output_dir}/result_${load}_update95lat_${thread}.csv
                grep "\[UPDATE\]\, 95thPercentileLatency" ${output_dir}/mongodb_run_test/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_update95lat_${thread}.csv
                echo "UPDATE-99thPercLat" > ${output_dir}/result_${load}_update99lat_${thread}.csv
                grep "\[UPDATE\]\, 99thPercentileLatency" ${output_dir}/mongodb_run_test/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_update99lat_${thread}.csv

		
		# RunTime 
		echo "Runtime(ms)" > ${output_dir}/result_runtime_${load}_thread_${thread}.csv
                grep "RunTime" ${output_dir}/mongodb_run_test/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_runtime_${load}_thread_${thread}.csv
	
		# read modify write - workloadf 	
		echo "READ-MODIFY-WRITE-95thPercLat" > ${output_dir}/result_${load}_readmodifywrite_thread_${thread}_95lat.csv
		grep "\[READ\-MODIFY\-WRITE\]\, 95thPercentileLatency" ${output_dir}/mongodb_run_test/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_readmodifywrite_thread_${thread}_95lat.csv

		echo "READ-MODIFY-WRITE-99thPercLat" > ${output_dir}/result_${load}_readmodifywrite_thread_${thread}_99lat.csv
		grep "\[READ\-MODIFY\-WRITE\]\, 99thPercentileLatency" ${output_dir}/mongodb_run_test/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_readmodifywrite_thread_${thread}_99lat.csv
	done
done 

for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do
	for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do
		paste -d',' ${output_dir}/result_${load}_threads_${thread}.csv \
				${output_dir}/result_runtime_${load}_thread_${thread}.csv \
			    	${output_dir}/result_${load}_read95lat_${thread}.csv \
			    	${output_dir}/result_${load}_read99lat_${thread}.csv \
			    	${output_dir}/result_${load}_update95lat_${thread}.csv \
			    	${output_dir}/result_${load}_update99lat_${thread}.csv \
			    	${output_dir}/result_${load}_readmodifywrite_thread_${thread}_95lat.csv \
		            	${output_dir}/result_${load}_readmodifywrite_thread_${thread}_99lat.csv > ${output_dir}/Throughput_lat_${load}_threads_${thread}.csv
	done 
done 
