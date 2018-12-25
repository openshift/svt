#!/bin/sh

CIRROS_CONFIG=config/golang/cnv_vm_cirros
FEDORA_CONFIG=config/golang/cnv_vm_fedora
set -x

if [ "$#" -ne 2 ]; then
  echo "syntax: $0 <TYPE>"
  echo "<TYPE> should be either golang or python"
  exit 1
fi

TYPE=$1
VM_TEST=$2

golang_clusterloader() {
  # set config file
  if [ $VM_TEST == 'cnv_vm_cirros' ]; then
    CONFIG=$CIRROS_CONFIG
    echo "Testing with cirros VM"
  elif  [ $VM_TEST == 'cnv_vm_fedora' ]; then
    CONFIG=$FEDORA_CONFIG
    echo "Testing with fedora VM"
  else
  	echo "Test VM did not set"
  	exit 1
  fi
  # Export kube config
  export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}
  # loading cluster based on yaml config file
  /usr/libexec/atomic-openshift/extended.test --ginkgo.focus="Load cluster" --viper-config=$CONFIG
}

echo "Startup delay + entropy collection"
sleep 5m

echo "Run tests"
if [ "$TYPE" == "golang" ]; then
  golang_clusterloader
else
  echo "$TYPE is not a valid option, available options: golang"
  exit 1
fi

echo "sleeping 15 minutes for settling after tests"
sleep 15m
