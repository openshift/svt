#!/bin/sh

if [ "$#" -ne 1 ]; then
  echo "syntax: $0 <TYPE>"
  echo "<TYPE> should be either golang or python"
  exit 1
fi

TYPE=$1

golang_clusterloader() {
  # Export kube config
  export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}
  MY_CONFIG=config/golang/cluster-limits-namespaces
  # loading cluster based on yaml config file
  /usr/libexec/atomic-openshift/extended.test --ginkgo.focus="Load cluster" --viper-config=$MY_CONFIG
}

python_clusterloader() {
  MY_CONFIG=config/cluster-limits-namespaces.yaml
  python cluster-loader.py -f $MY_CONFIG
}

echo "Startup delay + entropy collection" 
sleep 5m

echo "Run tests" 
if [ "$TYPE" == "golang" ]; then
  golang_clusterloader
elif [ "$TYPE" == "python" ]; then
  python_clusterloader
else
  echo "$TYPE is not a valid option, available options: golang, python"
  exit 1
fi

echo "sleeping 15 minutes for settling after tests"
sleep 15m
