#!/bin/sh

if [ "$#" -ne 1 ]; then
  echo "syntax: $0 <TYPE>"
  echo "<TYPE> should be either golang or python"
  exit 1
fi

TYPE=$1

long_sleep() {
  local sleep_time=180
  echo "Sleeping for $sleep_time"
  sleep $sleep_time
}

golang_clusterloader() {
  # Export kube config
  export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}
  MY_CONFIG=config/golang/cluster-limits-pods-per-namespace
  # loading cluster based on yaml config file
  /usr/libexec/atomic-openshift/extended.test --ginkgo.focus="Load cluster" --viper-config=$MY_CONFIG
}

python_clusterloader() {
  MY_CONFIG=config/cluster-limits-pods-per-namespace.yaml
  ./cluster-loader.py --file=$MY_CONFIG
}

# sleeping to gather some steady-state metrics, pre-test
long_sleep

# Run the test
if [ "$TYPE" == "golang" ]; then
  golang_clusterloader
elif [ "$TYPE" == "python" ]; then
  python_clusterloader
  # sleeping again to gather steady-state metrics after environment is loaded
  long_sleep
else
  echo "$TYPE is not a valid option, available options: golang, python"
  exit 1
fi

# sleep after test is complete to gather post-test metrics...these should be the same as pre-test
long_sleep
