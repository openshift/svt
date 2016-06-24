#!/bin/sh

# usage
# ./pbench-register.sh 
# pbench-user-benchmark -C testname -- ./mastervirt.sh
# pbench-move-results

echo "Startup delay + entropy collection" 
sleep 5m

echo "Run tests" 
python cluster-loader.py -f ./config/pyconfigMasterVirtScale.yaml

echo "sleeping 15 minutes for settling after tests"
sleep 15m