#!/bin/sh

if [ "$#" -ne 2 ]; then
  echo "syntax: $0 <TESTNAME> <TYPE>"
  echo "<TYPE> should be either golang or python"
  exit 1
fi

TESTNAME=$1
TYPE=$2

long_sleep() {
  local sleep_time=180
  echo "Sleeping for $sleep_time"
  sleep $sleep_time
}

clean() { echo "Cleaning environment"; oc delete project clusterproject0; }

golang_clusterloader() {
  # Export kube config
  export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}
  MY_CONFIG=config/golang/nodeVertical
  # loading cluster based on yaml config file
  /usr/libexec/atomic-openshift/extended.test --ginkgo.focus="Load cluster" --viper-config=$MY_CONFIG
}

python_clusterloader() {
  MY_CONFIG=config/nodeVertical.yaml
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
  # clean up environment
  clean
else
  echo "$TYPE is not a valid option, available options: golang, python"
  exit 1
fi

# TODO(himanshu): fix clean function
#./cluster-loader.py --clean

# sleep after test is complete to gather post-test metrics...these should be the same as pre-test
long_sleep
