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

function sanity_stepping() {
  stepping=$1
  pbench_user_benchmark=$(echo ${pbench_user_benchmark} |sed "s| --|_STEPPING${stepping} --|")
  ./prometheus-loader.sh 20 20 ${period} ${duration} ${enable_pbench} ${pbench_copy_results} ${pbench_user_benchmark} ${stepping}
}

# last 15min
sanity_stepping 5
# last 1 hour
sanity_stepping 15
# last 6 hour
sanity_stepping 30
# last 12 hours
sanity_stepping 120
# last 24 hours
sanity_stepping 300
# last week
sanity_stepping 1200

exit 0
