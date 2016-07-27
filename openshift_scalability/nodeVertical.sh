#!/bin/sh

if [ "$#" -ne 1 ]; then
  echo "syntax: $0 <TESTNAME>"
  exit 1
fi

TESTNAME=$1
MY_CONFIG=config/nodeVertical.yaml

long_sleep() {
  local sleep_time=180
  echo "Sleeping for $sleep_time"
  sleep $sleep_time
}

clean() { echo "Cleaning environment"; oc delete project clusterproject0; }

# sleeping to gather some steady-state metrics, pre-test
long_sleep

# loading cluster based on yaml config file
./cluster-loader.py --file=$MY_CONFIG

# sleeping again to gather steady-state metrics after environment is loaded
long_sleep

# clean up environment
clean

# TODO(himanshu): fix clean function
#./cluster-loader.py --clean

# sleep after test is complete to gather post-test metrics...these should be the same as pre-test
long_sleep
