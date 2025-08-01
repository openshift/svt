#!/bin/bash

BASENAME=${1:-mva}
NUM_PROJECTS=${2:-250}
PARALLEL=${3:-10}

CONFIG_TEMPLATE=config/apf_template.yaml
deletion_time=30
sleep=10

cp $CONFIG_TEMPLATE config/apf_run.yaml

sed -i "s/BASENAME/$BASENAME/g" config/apf_run.yaml
sed -i "s/NUM_PROJECTS/$NUM_PROJECTS/g" config/apf_run.yaml

date
SECONDS=0
python3 -m venv ./venv
source ./venv/bin/activate
pip3 install -r ./cluster_loader_requirements.txt
./cluster-loader.py -f config/apf_run.yaml -p "$PARALLEL"
deactivate

duration=$SECONDS
echo "Time taken: $duration"
date

#update 10 to real number
for i in {0..10}; do oc get pods -A | grep -v Running | grep -v Completed; echo; sleep 1m; done
date

for ((i=0; i<NUM_PROJECTS; i++)); do
  oc label ns "${BASENAME}${i} purpose=test"
done

oc project default
oc delete project -l purpose=test --wait=false

timeout=$(date -d "+$DELETION_TIMEOUT minutes" +%s)

while sleep $sleep_time; do
  number_of_terminating_projects=$(oc get projects | grep -c Terminating)
  echo -e "Number of terminating projects: $number_of_terminating_projects"
  if [[ $number_of_terminating_projects -eq 0 ]]; then
    echo -e "All test projects are deleted"
    break
  else
    if [[ $timeout < $(date +%s) ]]; then
      echo -e "ERROR: Timeout after $deletion_time. Not all projects were deleted."
      break
    fi
    echo -e "sleep for $sleep_time before next check"
  fi
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
