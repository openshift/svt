#!/bin/bash

##########################################################################################
## Author: skordas@redhat.com                                                           ##
## Description: Support script for project deletion test.                               ##
## Test case: Project deletion when one of nodes where pods are running are down        ##
## Polarion Test case: OCP-18155                                                        ##
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-18155 ##
##########################################################################################

no_xtrace=$1
wait_timeout=5 # Timeout in minutes
sleep_time=5 # Sleep time in seconds befteew checks

function log {
  echo -e "[$(date "+%F %T")]: $*"
}

if [[ $no_xtrace != "true" ]]; then
  set -x
fi


NUMBER_OR_RUNNING_WORKER_NODES=$(oc get nodes | grep worker | grep -c Ready)
echo "export NUMBER_OR_RUNNING_WORKER_NODES=$NUMBER_OR_RUNNING_WORKER_NODES" >> exports.sh
log "Getting machine where pods is running"
node_name=$(oc get pods -n "${NAMESPACE}-1" -o jsonpath='{.items[0].spec.nodeName}')
log "Node to delete: $node_name"
machine_name=$(oc get nodes -o jsonpath="{.items[?(@.metadata.name=='$node_name')].metadata.annotations.machine\.openshift\.io/machine}")
machine_name=$(echo "$machine_name" | cut -f 2 -d "/")
log "Machine to delete $machine_name"

oc delete machine "$machine_name" -n openshift-machine-api --wait=false

timeout=$(date -d "+$wait_timeout minutes" +%s)

while sleep $sleep_time; do
  if [[ $(oc get nodes | grep worker | grep -c SchedulingDisabled) -ge "1" ]]; then
    log "Some nodes are disabled for scheduling!"
    log "Continue with the test"
    break
  else
    if [[ $timeout < $(date +%s) ]]; then
      log "Timeout after $wait_timeout minutes."
      log "At least one working node should not be Ready"
      log "Test failed"
      oc get nodes
      oc get machineset -n openshift-machine-api
      oc get machines -n openshift-machine-api
      exit 1
    fi
    log "Sleep $sleep_time seconds before next check."
    continue
  fi
done

oc get machines -n openshift-machine-api
oc get nodes
