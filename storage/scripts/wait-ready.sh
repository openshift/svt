#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

LABEL=$1

while $(sleep 5); do
    result=$(oc get pods --all-namespaces --selector="name="${LABEL}"" --no-headers | awk '{print $3}' | awk -F/ '{print $1}' | tr ' ' '\n' | sort --numeric-sort | head --lines=1)

    if [[ -z "${result}" ]]; then
	exit 1
    fi

    if [[ "${result}" == 1 ]]; then
	exit 0
    fi
    
done
