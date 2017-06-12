#!/usr/bin/env bash
#  project where sysbench pods will be created
PROJECT="$1"

python cluster-loader.py -f ./sysbench-parameters.yaml

SPOD="$(oc get pods -n $PROJECT  | awk '{print $3}' | grep -v STATUS | grep Running | tail -1 )"
# wait till at least one pod is running state

while [ "$SPOD" != "Running" ]; do
    sleep 1
done

# as long as there are some pods in "Running" state - test is running
# we need this for pbench-user-benchmark

while [ "$SPOD" == "Running" ]; do
	sleep 60
	SPOD="$(oc get pods -n $PROJECT  | awk '{print $3}' | grep -v STATUS | grep Running | tail -1 )"
done


