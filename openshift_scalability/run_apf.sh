#!/bin/bash

BASENAME=${1:-mva}
NUM_PROJECTS=${2:-250}
PARALLEL=${3:-10}

CONFIG_TEMPLATE=config/apf_template.yaml

cp $CONFIG_TEMPLATE config/apf_run.yaml

sed -i "s/BASENAME/$BASENAME/g" config/apf_run.yaml
sed -i "s/NUM_PROJECTS/$NUM_PROJECTS/g" config/apf_run.yaml

date
SECONDS=0
./cluster-loader.py -f config/apf_run.yaml -p "$PARALLEL"
duration=$SECONDS
echo "Time taken: $duration"
date

#update 10 to real number
for i in {0..10}; do oc get pods -A | grep -v Running | grep -v Completed; echo; sleep 1m; done
date

for ((i=0; i<NUM_PROJECTS; i++)); do
  oc delete project "${BASENAME}${i}"
done

date


# Build config Init:Error, I think the script needs update to get from a git that is reachable
# build.build.openshift.io/buildconfig0-1   Source   Dockerfile,Git   Failed (FetchSourceFailed)   3 minutes ago   3m31s
# Describe the build config got:
# Log Tail:    Cloning "git://github.com/tiwillia/hello-openshift-example.git" ...
#         WARNING: timed out waiting for git server, will wait 1m4s
#         WARNING: timed out waiting for git server, will wait 4m16s
#         error: fatal: unable to connect to github.com:
#         github.com[0: 140.82.114.3]: errno=Connection timed out