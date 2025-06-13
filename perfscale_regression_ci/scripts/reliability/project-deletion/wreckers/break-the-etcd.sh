#!/bin/bash

##########################################################################################
## Author: skordas@redhat.com                                                           ##
## Description: Support script for project deletion test.                               ##
## Test case: Project deletion when ETCD is down                                        ##
## Polarion Test case: OCP-18155                                                        ##
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-18155 ##
##########################################################################################

no_xtrace=$1
sleep_time=5 # Sleep time in seconds between checks
wait_timeout=5 # Timeout in minutes

function log {
  echo -e "[$(date "+%F %T")]: $*"
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

MASTER_NODE_WITH_ETCD=$(oc get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/master)].metadata.name}' | cut -d ' ' -f 1)

# export MASTER_NODE_WITH_ETCD - it's needed for recovery script.
echo "export MASTER_NODE_WITH_ETCD=$MASTER_NODE_WITH_ETCD" >> exports.sh

log "Moving out etcd-pod manifest..."
oc debug node/"$MASTER_NODE_WITH_ETCD" -- chroot /host mv /etc/kubernetes/manifests/etcd-pod.yaml /root/

timeout=$(date -d "+$wait_timeout minutes" +%s)

while sleep $sleep_time; do
  etcd_pod_is_ready=$(get_etcd_pod_readiness)
  log "ETCD pod on $MASTER_NODE_WITH_ETCD readiness is: $etcd_pod_is_ready"
  if [[ $etcd_pod_is_ready != "true" ]]; then
    log "ETCD on $MASTER_NODE_WITH_ETCD node is down"
    log "Continue with the test..."
    break
  else
    if [[ $timeout < $(date +%s) ]]; then
      log "Timeout after $wait_timeout minutes."
      log "ETCD on $MASTER_NODE_WITH_ETCD node is not down"
      log "Test failed"
      exit 1
    fi
    log "Sleep $sleep_time seconds before next check."
  fi
done
