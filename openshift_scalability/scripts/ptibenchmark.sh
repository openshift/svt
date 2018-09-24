#!/bin/bash

# The following script will execture A B Benchmark for pti(spectre).

type=$1
aname=$2
bname=$3
cd `dirname $0` # Make sure to be at svt dir

#TODO: Abstract more nicely.

function usage() {
echo "
USAGE:
    nohup ./ptibenchmark.sh python ptienabled ptidisabled <script> <scriptargs> 2>&1 &
"
}

#TODO: handle empty args, defaults.

#A Test
for h in `oc get no |grep -v NAME|awk '{print $1}'`; do ssh $h "echo 1 > /sys/kernel/debug/x86/pti_enabled; echo 1 > /sys/kernel/debug/x86/ibpb_enabled; echo 1 > /sys/kernel/debug/x86/ibrs_enabled"; done
pbench-user-benchmark .././nodeVertical.sh $aname $type > /tmp/n.log
pbench-move-results --prefix=$aname

#B Test
for h in `oc get no |grep -v NAME|awk '{print $1}'`; do ssh $h "echo 0 > /sys/kernel/debug/x86/pti_enabled; echo 0 > /sys/kernel/debug/x86/ibpb_enabled; echo 0 > /sys/kernel/debug/x86/ibrs_enabled"; done
pbench-user-benchmark .././nodeVertical.sh $bname $type > /tmp/n.log
pbench-move-results --prefix=$bname

exit 0
