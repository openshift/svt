#!/bin/bash

INTERVAL=$1

if [[ -z "$INTERVAL" ]]; then
	INTERVAL=60
fi

while true;
do
	echo "$(date +'%m-%d-%y-%H:%M:%S') $(oc exec prometheus-k8s-0 -n openshift-monitoring -c prometheus -- df |grep -v tmp |grep '/prometheus')" >> ~/pvc_monitor_0.log
	echo "$(date +'%m-%d-%y-%H:%M:%S') $(oc exec prometheus-k8s-1 -n openshift-monitoring -c prometheus -- df |grep -v tmp |grep '/prometheus')" >> ~/pvc_monitor_1.log
	sleep $INTERVAL
done
exit 0
