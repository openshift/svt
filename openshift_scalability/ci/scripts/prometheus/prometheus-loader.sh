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

cd /root/svt/openshift_scalability # go to svt working dir

oc login -u system:admin
if [ "${enable_pbench}" == "true" ]; then
    for n in `oc get no |grep -v app |awk '{print $1}'`; do pbench-register-tool-set --remote=$n; done
fi

if [ -z "${stepping}" ]; then
    stepping=15
fi

# start the prometheus load.
nohup python prometheus-loader.py -f content/promethues/qs.txt -i ${refresh_interval} -t ${concurrency} -p ${graph_period} -r ${stepping} > /dev/null 2>&1 &
loader_pid=$(echo $!)
# sleep x hours, and monitor the load by pbench.
${pbench_user_benchmark} sleep ${duration}
# stop the promehteus load.
kill -9 $loader_pid
# dump logs
mkdir -p ${benchmark_run_dir}/promethues
oc logs prometheus-k8s-0 -c prometheus > ${benchmark_run_dir}/promethues/oc_logs.log
oc logs prometheus-k8s-1 -c prometheus >> ${benchmark_run_dir}/promethues/oc_logs.log
grep ERROR /tmp/prometheus_loader.log > ${benchmark_run_dir}/promethues/errors.log
grep duration /tmp/prometheus_loader.log |grep -v 'duration: 0' |awk '{print $7}' |sort > ${benchmark_run_dir}/promethues/top_longest_queries.log
rm -fr /tmp/prometheus_loader.log
# stop pbench and copy results.
${pbench_copy_results}
pbench-stop-tools
#TODO: analyze the logs and add pass criteria for this job.
exit 0
