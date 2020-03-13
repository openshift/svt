#!/bin/bash
NUM=$1
SLEEP=$2
while true; do 
   echo "============"
   oc get pods --all-namespaces | grep openshift | grep Running| awk {'print $1" "$2'} | shuf -n $NUM | while read i; do oc delete pod -n $i --wait=false; done; sleep $SLEEP; 
done
