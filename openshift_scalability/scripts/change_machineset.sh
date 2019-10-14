#!/bin/bash

# Usage: ./change_machineset.sh <machine number> '<json in json-patch format>' <timeout_in_minutes>
# Example to change from 3 machinesets in 3 different zones to 3 in one zone with different type and volumeSize:

# bash change_machineset.sh 1 '[{"op": "replace", "path": "/spec/replicas", "value": 0}]' 5
# bash change_machineset.sh 1 '[{"op": "replace", "path": "/spec/template/spec/providerSpec/value/blockDevices/0/ebs/volumeSize", "value": 100}]' 5
# bash change_machineset.sh 1 '[{"op": "replace", "path": "/spec/template/spec/providerSpec/value/instanceType", "value": "m5.4xlarge"}]' 5
# bash change_machineset.sh 1 '[{"op": "replace", "path": "/spec/replicas", "value": 3}]' 20
# bash change_machineset.sh 2 '[{"op": "replace", "path": "/spec/replicas", "value": 0}]' 5
# bash change_machineset.sh 3 '[{"op": "replace", "path": "/spec/replicas", "value": 0}]' 5

function log {
    echo -e "[$(date "+%F %T")]: $*"
}

function get_machineset() {
    machinesets=($(oc get machineset --no-headers -n openshift-machine-api | awk '{print $1}'))
    echo ${machinesets[$1-1]} # minus one, to use machineset count from 1
}

function wait_until_machineset_is_available() {
    desired=$(oc get machineset $1 -n openshift-machine-api --no-headers | awk '{print $2}')
    timeout=$(($2*60))
    if [[ $desired == 0 ]]; then
        start_time=$(date +%s)
        while (( ($(date +%s) - ${start_time}) < ${timeout} ));
        do
            scheduled=$(oc get nodes | grep -c SchedulingDisabled)
            if [[ $scheduled == 0 ]]; then
                log "Machineset $1 is set to 0"
                exit 0
            fi
            log "Machineset $1 is not ready yet. Waiting for nodes to be ready. Next check in 30 seconds..."
            sleep 30
        done
        log "Timeout!!!!"
        exit 1
    else
        start_time=$(date +%s)
        while (( ($(date +%s) - ${start_time}) < ${timeout} ));
        do
            available=$(oc get machineset $1 -n openshift-machine-api --no-headers | awk '{print $5}')
            if [[ $desired == $available ]]; then
                log "Machineset $1 is ready. Available $available"
                exit 0
            fi
            log "Machineset $1 is not ready yet. Waiting for $desired available. Next check in 30 seconds..."
            sleep 30
        done
        log "Timeout!!!!"
        exit 1
    fi
}

machineset=$(get_machineset $1)
log "Machineset to patch:\n$machineset"

cmd=(oc patch machineset $machineset -n openshift-machine-api --type=json --patch=\'$2\')
echo ${cmd[@]}
eval ${cmd[@]}

sleep 5
wait_until_machineset_is_available $machineset $3
