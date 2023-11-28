#!/bin/bash
# Pre-requisite: m6i.xlarge 4.x cluster with 10 worker nodes and oc client installed. (prior to 4.11, m5.2xlarge)
# For accurate performance results all the nodes have to be in the same AWS availability zone
# Author : rpattath@redhat.com

echo 'Create 200 projects and create 1 dc in each project'
time for i in {0..199}; do oc new-project --skip-config-write test$i; oc create -n test$i -f dc.json; done > /tmp/octime
echo 'for each of 200 projects, get the dcs, sa and secrets'
time for i in {0..199}; do oc get dc -n test$i; oc get sa -n test$i; oc get secrets -n test$i; done >> /tmp/octime
echo 'for each of 200 projects, scale the dc replicas to 0'
time for i in {0..199}; do oc scale --replicas=0 dc/deploymentconfig1 -n test$i; done >> /tmp/octime
echo 'Delete 200 projects'
time for i in {0..199}; do oc delete project --wait=false test$i; done >> /tmp/octime
