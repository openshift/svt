#!/bin/bash
set -x

refresh_interval=$1
concurrency=$2
duration=$3
enable_pbench=$4
pbench_copy_results=$5
pbench_user_benchmark=$6

cd /root/svt/openshift_scalability # go to svt working dir

# replace with init script
oc login -u system:admin
if [ "${enable_pbench}" == "true" ]; then
    pbench-register-tool-set
fi

function sanity_period() {
  period=$1
  pbench_user_benchmark=$(echo ${pbench_user_benchmark} |sed -e "s|PERIOD${GRAPH_PERIOD} --|PERIOD${period} --|")
  ./prometheus-loader.sh 20 20 ${period} ${duration} ${enable_pbench} ${pbench_copy_results} ${pbench_user_benchmark}
}

# last 15min
sanity_period 15
# last 1 hour
sanity_period 60
# last 6 hour
sanity_period 360
# last 12 hours
sanity_period 720
# last 24 hours
sanity_period 1440
# last week
sanity_period 10080

exit 0
