#!/bin/bash

set -eo pipefail

output_dir=$1
prometheus_namespace=openshift-monitoring

if [[ "$#" -ne 1 ]]; then
	 echo "syntax: $0 <output_dir>"
	 exit 1
fi

# Check for kubeconfig
if [[ -z $KUBECONFIG ]] && [[ ! -s $HOME/.kube/config ]]; then
        echo "KUBECONFIG var is not defined and cannot find kube config in the home directory, please check"
        exit 1
fi

# Check if oc client is installed
which oc &>/dev/null
echo "Checking if oc client is installed"
if [[ $? != 0 ]]; then
        echo "oc client is not installed, please install"
        exit 1
else
	echo "oc client is present"
fi

# pick a prometheus pod
prometheus_pod=$(oc get pods -n $prometheus_namespace | grep -w "Running" | awk -F " " '/prometheus-k8s/{print $1}' | tail -n1)

# copy the prometheus DB from the prometheus pod
echo "copying prometheus DB from $prometheus_pod"
oc cp $prometheus_namespace/$prometheus_pod:/prometheus/wal -c prometheus wal/
echo "creating a tarball of the captured DB at $output_dir"
XZ_OPT=--threads=0 tar cJf $output_dir/prometheus.tar.xz wal
if [[ $? == 0 ]]; then
	rm -rf wal
fi
