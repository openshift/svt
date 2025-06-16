#!/bin/bash

##########################################################################################
## Author: skordas@redhat.com                                                           ##
## Description: Tests for deleting priojects under different conditions.                ##
## Polarion Test case: OCP-18155                                                        ##
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-18155 ##
## Run:                                                                                 ##
## ./project-deletion-test.sh delete_node                                               ##
##           to run test project deletion where node where pods are running are down    ##
##                                                                                      ##
## ./project-deletion-test.sh etcd_is_down                                              ##
##           to run test project deletion when one etcd service is down                 ##
##                                                                                      ##
## set 'true' as a second parameter to not print comands as they are executed           ##  
##########################################################################################

test=$1
no_xtrace=$2
tests=("delete_node" "etcd_is_down")

declare sleep_time=5 # Sleep time in seconds between checks
export delete_project_test_passed=false # To store main test result through the script.

export NUMBER_OF_ETCD_PODS="" # Used for passing number of ETCD nodes - later used in recovery script. 
export NAME=${NAME:-"project-deletion-tests"} # Used for labeling project
export NAMESPACE=${NAMESPACE:-"project-to-delete"} # Name for projects
export PARAMETERS=${PARAMETERS:-15} # Number of projects to delete
export DELETION_TIMEOUT=${DELETION_TIMEOUT:-5} # Time out for deletion of projects in minutes

function log {
  echo -e "[$(date "+%F %T")]: $*"
}

if [[ $no_xtrace != "true" ]]; then
  set -x
fi

## STEP 0 - before - checking if correct parameter is passed
if [[ ${tests[*]} =~ $test ]]; then
	log "========  Test to run: $test  ========"
else
	log "Please read the description of the script and pass correct parameter"
	exit 1
fi

## STEP 1 - Load cluster
log "Loading cluster...."
pushd ../../scalability/ || exit
./loaded-projects.sh
popd || exit

## STEP 2 - Break something!
set -e
case $test in
	delete_node)
		log "Running test: Delete projects - node where pods are running is down."
		./wreckers/break-the-machine.sh "$no_xtrace"
		;;
	etcd_is_down)
		log "Running test: Delete projects - one of etcd is down"
		./wreckers/break-the-etcd.sh "$no_xtrace"
		;;
esac
set +e

## STEP 3 - Delete projects
log "Deleting projects..."
oc project default
oc delete project -l kube-burner-job="$NAME" --wait=false

timeout=$(date -d "+$DELETION_TIMEOUT minutes" +%s)

while sleep $sleep_time; do
	number_of_terminating_projects=$(oc get projects | grep -c Terminating)
	log "Number of Terminating projects: $number_of_terminating_projects"
	if [[ $number_of_terminating_projects -eq 0 ]]; then
		delete_project_test_passed=true
		log "All projects are deleted!"
		log "Continue with test..."
    break
  else
  	if [[ $timeout < $(date +%s) ]]; then
  		log "Timeout after $DELETION_TIMEOUT. Not all projects were deleted."
  		log "!!!!!!!!  Test failed  !!!!!!!!"
  	fi
  	log "Sleep $sleep_time seconds before next check."
  	continue
	fi
done

## STEP 4 - Be sure what you broke before deletion will work fine before moving forward.
set -e
case $test in
  delete_node)
  	log "Checking if all nodes are available."
  	./wreckers/break-the-machine-recovery.sh "$no_xtrace"
  	;;
  etcd_is_down)
  	log "Recover ETCD failover"
  	./wreckers/break-the-etcd-recovery.sh "$no_xtrace"
  	;;
esac
set +e

## STEP 5 - after - verification of results
if [[ $delete_project_test_passed == true ]]; then
	rm -f exports.sh
	log "TEST: $test PASSED!!!"
	log "========     END OF THE TEST     ========"
else
	log "TEST: $test FAILED!!!"
  oc get projects
  oc get nodes
  oc get machineset -n openshift-machine-api
  oc get machines -n openshift-machine-api
  exit 1
fi

