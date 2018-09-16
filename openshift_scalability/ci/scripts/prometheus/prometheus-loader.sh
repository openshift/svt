#!/bin/bash
set -x

refresh_interval=$1
concurrency=$2
graph_period=$3
duration=$4
enable_pbench=$5
pbench_copy_results=$6
pbench_user_benchmark=$7
stepping=$8

oc login -u system:admin
if [ "${enable_pbench}" == "true" ]; then
    pbench-register-tool-set
fi

if [ -z "${stepping}" ]; then
    stepping=15
fi

function db_aging() {
  while true;
    echo "$(date +'%m-%d-%y-%H:%M:%S') $(oc exec prometheus-k8s-0 -n openshift-monitoring -c prometheus -- df |grep -v tmp |grep '/prometheus')" >> ${benchmark_run_dir}/promethues/pvc_monitor_0.log
    echo "$(date +'%m-%d-%y-%H:%M:%S') $(oc exec prometheus-k8s-1 -n openshift-monitoring -c prometheus -- df |grep -v tmp |grep '/prometheus')" >> ${benchmark_run_dir}/promethues/pvc_monitor_1.log
}
# start the prometheus load.
nohup python prometheus-loader.py ${refresh_interval} -t ${concurrency} -p ${graph_period} -r ${stepping} > /dev/null 2>&1 &
loader_pid=$(echo $!)
#db grow monitor
nohup db_aging > /dev/null 2>&1 &
db_aging_pid=$(echo $!)
# sleep x hours, and monitor the load by pbench.
${pbench_user_benchmark} sleep ${duration}; sleep 10; pbench-stop-tools
# stop pbench and copy results.
${pbench_copy_results}
# stop the promehteus load.
kill -9 $loader_pid $db_aging_pid
# dump logs
mkdir -p ${benchmark_run_dir}/promethues
oc logs prometheus-k8s-0 -c prometheus > ${benchmark_run_dir}/promethues/oc_logs.log
oc logs prometheus-k8s-1 -c prometheus >> ${benchmark_run_dir}/promethues/oc_logs.log
grep ERROR /tmp/prometheus_loader.log > ${benchmark_run_dir}/promethues/errors.log
grep duration /tmp/prometheus_loader.log |grep -v 'duration: 0' |awk '{print $7}' |sort > ${benchmark_run_dir}/promethues/top_longest_queries.log
rm -fr /tmp/prometheus_loader.log
#TODO: analyze the logs and add pass criteria for this job.
exit 0
