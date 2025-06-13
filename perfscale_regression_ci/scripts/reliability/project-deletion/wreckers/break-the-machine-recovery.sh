#!/bin/bash

##########################################################################################
## Author: skordas@redhat.com                                                           ##
## Description: Support script for project deletion test - check after test.            ##
## Test case: Project deletion when one of nodes where pods are running are down        ##
## Polarion Test case: OCP-18155                                                        ##
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-18155 ##
##########################################################################################

no_xtrace=$1
wait_timeout=10 # Timeout in minutes
sleep_time=30 # Sleep time in seconds between checks.

source ./exports.sh

function log {
  echo -e "[$(date "+%F %T")]: $*"
}

if [[ $no_xtrace != "true" ]]; then
  set -x
fi

timeout=$(date -d "+$wait_timeout minutes" +%s)

log "Waiting for $NUMBER_OR_RUNNING_WORKER_NODES worker nodes to be ready!"

while sleep $sleep_time; do
  if [[ $NUMBER_OR_RUNNING_WORKER_NODES -eq $(oc get nodes | grep worker | grep -v SchedulingDisabled | grep -v NotReady | grep -c Ready) ]]; then
    log "All $NUMBER_OR_RUNNING_WORKER_NODES worker nodes are ready"
    log "List of nodes:"
    oc get nodes
    log "List of machines"
    oc get machines -n openshift-machine-api
    log "Continue..."
    break
  else
    if [[ $timeout < $(date +%s) ]]; then
      log "Timeout after $wait_timeout mitunes"
      log "Not all nodes are ready"
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

