#!/bin/bash
set -x

refresh_interval=$1
concurrency=$2
graph_period=$3
duration=$4
enable_pbench=$5
pbench_copy_results=$6
pbench_user_benchmark=$7
test_name=$8

function db_aging() {
  while true; do
    echo "$(date +'%m-%d-%y-%H:%M:%S') $(oc exec prometheus-k8s-0 -n openshift-monitoring -c prometheus -- df |grep -v tmp |grep '/prometheus')" >> /tmp/pvc_monitor_0.log
    echo "$(date +'%m-%d-%y-%H:%M:%S') $(oc exec prometheus-k8s-1 -n openshift-monitoring -c prometheus -- df |grep -v tmp |grep '/prometheus')" >> /tmp/pvc_monitor_1.log
    sleep 120
  done
}

# start the prometheus load.
nohup python prometheus-loader.py -g True -p ${graph_period} > /dev/null 2>&1 &
loader_pid=$(echo $!)

#db grow monitor
export -f db_aging
nohup bash -c db_aging > /dev/null 2>&1 &
db_aging_pid=$(echo $!)

# sleep x hours, and monitor the load by pbench.
${pbench_user_benchmark} sleep ${duration};

# stop the promehteus load.
kill -9 $loader_pid $db_aging_pid

# test idle
sleep 300

# dump logs
benchmark_run_dir="/var/lib/pbench-agent/$(ls -t /var/lib/pbench-agent/ |grep "${test_name}" |head -1)"
oc logs -n openshift-monitoring prometheus-k8s-0 -c prometheus --since=${duration}s > ${benchmark_run_dir}/1/reference-result/oc_logs_1.log
oc logs -n openshift-monitoring prometheus-k8s-1 -c prometheus --since=${duration}s > ${benchmark_run_dir}/1/reference-result/oc_logs_2.log
grep ERROR /tmp/prometheus_loader.log > ${benchmark_run_dir}/1/reference-result/errors.log
cat /tmp/prometheus_loader.log |grep duration |grep -v GET |grep -v 'duration: 0' |awk '{print $7 " " $13}' |sort > ${dir}/1/reference-result/top_longest_queries.log
mv /tmp/pvc_monitor_0.log ${benchmark_run_dir}/1/reference-result/
mv /tmp/pvc_monitor_1.log ${benchmark_run_dir}/1/reference-result/

# stop pbench and copy results.
${pbench_copy_results}

# cleanup
rm -fr /tmp/prometheus_loader.log /tmp/pvc_monitor_0.log /tmp/pvc_monitor_1.log

#TODO: analyze the logs and add pass criteria for this job.
exit 0
