#!/bin/bash
set -x

refresh_interval=$1
concurrency=$2
graph_period=$3
duration=$4
enable_pbench=$5
pbench_copy_results=$6
pbench_user_benchmark=$7

cd /root/svt/openshift_scalability
# TODO: get the script file, remove this once the PR merged.
wget https://raw.githubusercontent.com/mrsiano/svt/prometheus_loader/openshift_scalability/prometheus-loader.py
wget https://raw.githubusercontent.com/mrsiano/svt/prometheus_loader/openshift_scalability/content/prometheus/qs.txt

oc login -u system:admin
if [ "${enable_pbench}" == "true" ]; then
    pbench-register-tool-set
fi
# start the prometheus load.
nohup python prometheus-loader.py -f ./qs.txt -i ${refresh_interval} -t ${concurrency} -p ${graph_period}  > /dev/null 2>&1 &
loader_pid=$(echo $!)
# sleep 2.5 hours, and monitor the load by pbench.
${pbench_user_benchmark} sleep ${duration}
# stop pbench and copy results.
${pbench_copy_results}
# stop the promehteus load.
kill -9 $loader_pid
exit 0
