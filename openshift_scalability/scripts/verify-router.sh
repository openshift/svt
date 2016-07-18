#!/bin/bash


# Script to verify a running router on OpenShift
# If IP address of the master node is not given, this must be run on the master node

set -o errexit
set -o nounset
set -o pipefail

MASTER_IP=${1:-127.0.0.1}

# checks that router service exists in the 'default' namespace
if ! $(oc adm router --dry-run --namespace default); then
    echo "router service doesn't exit"
    exit 1
fi

# curl healthz endpoint for router
if ! $(curl --head --fail ${MASTER_IP}:1936/healthz); then
    echo "router pod is not running"
    exit 1
fi
