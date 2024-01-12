#!/bin/bash
################################################
## Author: qili@redhat.com
## Description: Script for pod created/deleted continuously over time with same name, ensure serivce works
## Task: https://issues.redhat.com/browse/OCPQE-12153
################################################

echo "[INFO] Start test case 'create-delete-pod-ensure-service"
ns="create-delete-pod-ensure-service"
name="hello-openshift"
oc get project $ns || oc new-project $ns
oc get po $name -n $ns || oc create -f https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json -n $ns
oc get service $name -n $ns || oc expose pod $name -n $ns
oc get route $name -n $ns || oc expose svc $name -n $ns
echo "[INFO] Wait 10s after exposing svc before getting route"
sleep 10
route=$(oc get route -n $ns --no-headers | awk '{print $2}')
if [[ $route -ne 200 ]]; then
    echo "[FAIL] Route $route is not available."
    exit 1
fi
code=$(curl $route -s -w "%{http_code}" -o /dev/null)
if [[ code -ne 200 ]]; then
    echo "[FAIL] Curling $route got response code $code"
    exit 1
fi

oc delete po $name -n $ns && oc create -f https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json -n $ns
echo "[INFO] Wait 20s for the service to discover the new pod"
sleep 20
code=$(curl $route -s -w "%{http_code}" -o /dev/null)

if [[ code -eq 200 ]]; then
    echo "[PASS] Curling $route got response code $code"
    exit 0
else
    echo "[FAIL] Curling $route got response code $code"
    exit 1
fi