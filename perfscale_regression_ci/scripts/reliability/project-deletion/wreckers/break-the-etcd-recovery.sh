#!/bin/bash

##########################################################################################
## Author: skordas@redhat.com                                                           ##
## Description: Support script for project deletion test - check after test.            ##
## Test case: Project deletion when ETCD is down                                        ##
## Polarion Test case: OCP-18155                                                        ##
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-18155 ##
##########################################################################################

no_xtrace=$1
sleep_time=5    # Sleep time in seconds between checks.
wait_timeout=15 # Timeout in minutes

function log {
  echo -e "[$(date "+%F %T")]: $*"
}

function get_number_available_etcd_pods {
  number_of_pods=$(oc get pods -o wide -n openshif-etcd | grep "$MASTER_NODE_WITH_ETCD" | great -c Ready)
  echo "$number_of_pods"
}

function get_etcd_pod_readiness {
  # Can't use jsonpath here - can't filter by two variables.
  # https://github.com/kubernetes/kubernetes/issues/20352
  is_ready=$(oc get pods -n openshift-etcd -o json | jq -r --arg MASTER_NODE_WITH_ETCD "$MASTER_NODE_WITH_ETCD" '.items[] | select(.spec.nodeName==$MASTER_NODE_WITH_ETCD and .metadata.labels.app=="guard").status.containerStatuses[].ready')
  echo "$is_ready"
}

if [[ $no_xtrace != "true" ]]; then
  set -x
fi

log "Moving back etcd-pod manifest..."

# Getting exported values by etcd wreck script
source exports.sh

oc project default
oc debug node/"$MASTER_NODE_WITH_ETCD" -- chroot /host mv /root/etcd-pod.yaml /etc/kubernetes/manifests/

timeout=$(date -d "+$wait_timeout minutes" +%s)

while sleep $sleep_time; do
  etcd_pod_is_ready=$(get_etcd_pod_readiness)
  if [[ $etcd_pod_is_ready == "true" ]]; then
    log "ETCD on $MASTER_NODE_WITH_ETCD node is up again"
    log "Continue with test..."
    break
  else
    if [[ $timeout < $(date +%s) ]]; then
      log "Timeout after $wait_timeout minutes"
      log "ETCD on $MASTER_NODE_WITH_ETCD node is not up!"
      log "Test failed"
      exit 1
    fi
    log "Sleep $sleep_time seconds before next check"
  fi
done
