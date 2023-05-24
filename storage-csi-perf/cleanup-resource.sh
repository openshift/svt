#!/bin/bash
STATEFULSET_NAME=`oc get statefulset -n perfscale-storage -ojsonpath="{.items[*].metadata.name}"`
if [[ -z ${STATEFULSET_NAME} ]];then
	echo "No statefulset was found in project perfscale-storage"
else
	echo "Delete statefulset ${STATEFULSET_NAME} in project perfscale-storage"
	oc delete statefulset ${STATEFULSET_NAME} -n perfscale-storage
fi
sleep 30s
DEPLOYMENT_NAMES=`oc get deployment -n perfscale-storage -ojsonpath={.items[*].metadata.name}`
if [[ -z ${DEPLOYMENT_NAMES} ]];then
	echo "No deployment was found in project perfscale-storage"
else
	for NAME in $DEPLOYMENT_NAMES
	do
	   oc delete deployment $NAME -n perfscale-storage
	done
fi

sleep 30s
oc get ns |grep perfscale-storage
if [[ $? -eq 0 ]];then
   echo "Will delete project perfscale-storage"
   oc delete ns perfscale-storage
fi
sleep 30s
oc get  sc |grep in-tree
if [[ $? -eq 0 ]];then
	echo "Will delete in-tree storage class"
        SC_NAME=`oc get sc |grep in-tree|awk '{print $1}'`
	oc delete sc $SC_NAME
fi
