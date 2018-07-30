#!/bin/sh

if [ "$#" -ne 2 ]; then
  echo "syntax: $0 <TYPE>"
  echo "<TYPE> should be either golang or python"
  echo "<CONFIG> config file shold be one of config the files under ./config/"
  echo "example:"
  echo "./podVertical golang ./config/golang/cluster-limits-pods-per-namespace"
  exit 1
fi

TYPE=$1
CONFIG=$2

long_sleep() {
  local sleep_time=180
  echo "Sleeping for $sleep_time"
  sleep $sleep_time
}

golang_clusterloader() {
  # Export kube config
  export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}
  # loading cluster based on yaml config file
  /usr/libexec/atomic-openshift/extended.test --ginkgo.focus="Load cluster" --viper-config=$CONFIG
}

python_clusterloader() {
  ./cluster-loader.py --file=$CONFIG
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
