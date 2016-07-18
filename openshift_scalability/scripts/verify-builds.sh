#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Script to verify that all builds have completed
# Assumes there are no prior builds in the environment

# timeout in seconds, defaults to 30 minutes
TIMEOUT=${1:-1800}

# polling interval
INTERVAL=60

while sleep ${INTERVAL}; do
    BUILD_STATUSES=$(oc get builds --template '{{range .items}}{{printf "%s\n" .status.phase}}{{end}}' --all-namespaces)
    
    # check if builds are still pending
    for status in ${BUILD_STATUSES}; do
	if [[ ${status} == 'Pending' ]]; then 
	    echo "Builds still pending"
	    continue
	fi
    done

    # check if builds are still running
    for status in ${BUILD_STATUSES}; do
	if [[ ${status} == 'Running' ]]; then 
	    echo "Builds still running"
	    continue
	fi
    done

    # after builds are out of 'Pending' and 'Running' state, check if any aren't 'Complete'
    for status in ${BUILD_STATUSES}; do 
	if ! [[ ${status} == 'Complete' ]]; then
	    FAILED_BUILDS=$(oc get builds --template '{{range .items}}{{if ne .status.phase "Complete"}}{{printf "%s\n" .metadata.name}}{{end}}{{end}}' --all-namespaces)
	    
	    FAILED_NUMBER=$(echo "$FAILED_BUILDS" | wc -l)

	    echo "Number of failed builds: ${FAILED_NUMBER}"

	    echo "---------------------------"

	    echo "${FAILED_BUILDS}"

	    exit 1
	fi
    done


    if [[ ${SECONDS} -gt ${TIMEOUT} ]]; then
	echo "TIMEOUT: ${TIMEOUT} reached"
	exit 1
    fi
done
