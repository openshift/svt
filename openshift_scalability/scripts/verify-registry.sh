#!/bin/bash


# Script to verify a running Docker registry on OpenShift
# Must be run on a master/node in the cluster to be able to resolve the registry service IP address

set -o errexit
set -o nounset
set -o pipefail

# checks that docker-registry service exists in the 'default' namespace
if ! $(oc adm registry --dry-run --namespace default); then
    echo "docker-registry service doesn't exit"
    exit 1
fi

# get IP address of docker-registry service
REGISTRY_IP=$(oc get services --template '{{range .items}}{{if eq .metadata.name "docker-registry"}}{{printf "%s\n" .spec.clusterIP}}{{end}}{{end}}' --namespace default)

# curl $REGISTRY_IP:5000 to verify docker-registry pod is running
if ! $(curl --head --fail ${REGISTRY_IP}:5000); then
    echo "docker-registry pod is not running"
    exit 1
fi
