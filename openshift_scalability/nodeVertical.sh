#!/bin/sh

if [ "$#" -ne 1 ]; then
                echo "syntax: $0 <TESTNAME>"
                exit 1
fi

TESTNAME=$1
SLEEP=180
MYCONFIG=config/nodeVertical.yaml
CLEAN="oc delete project clusterproject0"

# sleeping to gather some steady-state metrics, pre-test
sleep $SLEEP

# loading cluster based on yaml config file
./cluster-loader.py --file=$MYCONFIG

# sleeping again to gather steady-state metrics after environment is loaded
echo sleeping for $SLEEP
sleep $SLEEP

# clean up environment
echo Cleaning environment
$CLEAN

# --clean function is broken, himanshu is working on fixing it
#./cluster-loader.py --clean

oc delete project clusterproject0

# sleep after test is complete to gather post-test metrics...these should be the same as pre-test
echo sleeping for $SLEEP
sleep $SLEEP
