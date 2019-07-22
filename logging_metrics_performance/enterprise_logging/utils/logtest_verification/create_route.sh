#!/bin/bash
# Helper bash script to create a route for elasticsearch
# Make sure to properly source this script before running to properly export vars ex: . ./create_route.sh
# You should be logged in as kubeadmin or some other user on the cluster that has a token

mkdir tmp
rm tmp/admin-ca tmp/els_route.yaml &> /dev/null
oc extract -n openshift-logging secret/elasticsearch --to=tmp/ --keys=admin-ca
cp templates/els_route.yaml tmp/
cat tmp/admin-ca | sed -e "s/^/      /" >> tmp/els_route.yaml
oc create -f tmp/els_route.yaml
oc get route -n openshift-logging elasticsearch -o jsonpath={.spec.host} > tmp/route
oc whoami -t > tmp/token
export ELS_ROUTE=$(cat tmp/route);
export ELS_TOKEN=$(cat tmp/token)

rm tmp/admin-ca
rm tmp/els_route.yaml