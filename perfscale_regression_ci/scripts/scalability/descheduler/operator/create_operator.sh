#/!/bin/bash

if [[ ! "$(pwd)" =~ "operator" ]]; then
    cd operator
    ls
    pwd
fi

source env.sh
source ../../../common.sh

#must be kubeadmin

env

if [[ -z $(oc get ns | grep $DESCH_NAMESPACE) ]]; then 
    echo "create ns"
    oc create ns $DESCH_NAMESPACE
fi

oc project $DESCH_NAMESPACE

# # Create the operatorgroup if it doesn't exist
if [[ -z $(oc get operatorgroup $operator_group_name -n $DESCH_NAMESPACE) ]]; then 
    echo "create operator group"

    echo "namesapce $DESCH_NAMESPACE"
    oc process -f operatorgroup.yaml -p=NAME=$operator_group_name -p=DESCH_NAMESPACE=$DESCH_NAMESPACE | oc create -f -
            
    oc get operatorgroup $operator_group_name -n $DESCH_NAMESPACE 
else 
    echo "operatorgroup already exists"
fi 


if [[ -z $(oc get subscription $DESCH_NAME -n $DESCH_NAMESPACE) ]]; then 
    # # Create the subscription")
    oc process -f subscription.yaml -p=NAME=$DESCH_NAME -p=DESCH_NAMESPACE=$DESCH_NAMESPACE -p=CHANNELNAME=$CHANNELNAME -p=OPSRCNAME=$OPSRCNAME -p=SOURCENAME=$SOURCENAME | oc create -f -
    # Wait for the descheduler operator pod running
    wait_for_obj_creation descheduler-operator pod
    sleep 15
else 
    echo "subscription already exists"
fi 
# get image 
version=$(oc get packagemanifest cluster-kube-descheduler-operator -o jsonpath=='{.status.channels[0].currentCSVDesc.version}')

image=$(oc get packagemanifest cluster-kube-descheduler-operator -o jsonpath=='{.status.channels[0].currentCSVDesc.relatedImages[1]}')

# wait for kube descheduler type 
# "the server doesn't have a resource type"
wait_for_object_type KubeDescheduler

if [[ -n $(oc get KubeDescheduler cluster -n $DESCH_NAMESPACE) ]]; then
    echo "delete kube descheduler"
    oc delete KubeDescheduler cluster -n $DESCH_NAMESPACE --wait
    wait_for_termination cluster KubeDescheduler
fi

# create kube scheduler cluster
if [[ -n $UTILIZATION_THRESHOLD ]]; then 
    echo "utilization threshold"
    oc process -f utilization_kubedescheduler.yaml -p=DESCH_NAMESPACE=$DESCH_NAMESPACE -p=INTERSECONDS=$INTERSECONDS -p=OPERATORLOGLEVEL=$OPERATORLOGLEVEL -p=IMAGEINFO=$image -p=LOGLEVEL=$LOGLEVEL -p=PROFILE1=$PROFILE1 -p=UTILIZATION_THRESHOLD=$UTILIZATION_THRESHOLD | oc create -f -
elif [[ -z $PROFILE2 ]]; then
    echo "profile"
    oc process -f kubedescheduler.yaml -p=DESCH_NAMESPACE=$DESCH_NAMESPACE -p=INTERSECONDS=$INTERSECONDS -p=OPERATORLOGLEVEL=$OPERATORLOGLEVEL -p=IMAGEINFO=$image -p=LOGLEVEL=$LOGLEVEL -p=PROFILE1=$PROFILE1 | oc create -f -
else
    echo "profile 2"
    oc process -f kubedescheduler2.yaml -p=DESCH_NAMESPACE=$DESCH_NAMESPACE -p=INTERSECONDS=$INTERSECONDS -p=OPERATORLOGLEVEL=$OPERATORLOGLEVEL -p=IMAGEINFO=$image -p=LOGLEVEL=$LOGLEVEL -p=PROFILE1=$PROFILE1 -p=PROFILE2=$PROFILE2 | oc create -f -
fi 


wait_for_app_pod_running $DESCH_NAMESPACE 1 descheduler


oc project default

if [[ "$(pwd)" == *"operator"* ]]; then
    echo "cd back a folder"
    cd ..
fi