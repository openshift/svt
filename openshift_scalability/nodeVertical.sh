#!/bin/sh

if [ "$#" -ne 3 ]; then
  echo "syntax: $0 <TESTNAME> <TYPE> <ENVIRONMENT>"
  echo "<TYPE> should be either golang or python"
  echo "<ENVIRONMENT> should be either alderaan or aws"
  exit 1
fi

TESTNAME=$1
TYPE=$2
ENVIRONMENT=$3
LABEL="node-role.kubernetes.io/compute=true"
CORE_COMPUTE_LABEL="core_app_node=true"
TEST_LABEL="nodevertical=true"
declare -a CORE_NODES
NODE_COUNT=0
pod_count=0

long_sleep() {
  local sleep_time=180
  echo "Sleeping for $sleep_time"
  sleep $sleep_time
}

clean() { echo "Cleaning environment"; oc delete project clusterproject0; }

golang_clusterloader() {
  # Export kube config
  export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}
  if [[ "$ENVIRONMENT" == "alderaan" ]]; then
  	MY_CONFIG=config/golang/nodeVertical-labeled-nodes
	sed -i "/- num: 1000/c \ \ \ \ \ \ \ \ \- num: $total_pod_count" /root/svt/openshift_scalability/config/golang/nodeVertical-labeled-nodes.yaml
  else
  	MY_CONFIG=config/golang/nodeVertical
	sed -i "/- num: 1000/c \ \ \ \ \ \ \ \ \- num: $total_pod_count" /root/svt/openshift_scalability/config/golang/nodeVertical.yaml
  fi
  # loading cluster based on yaml config file
  /usr/libexec/atomic-openshift/extended.test --ginkgo.focus="Load cluster" --viper-config=$MY_CONFIG
}

python_clusterloader() {
  MY_CONFIG=config/nodeVertical.yaml
  ./cluster-loader.py --file=$MY_CONFIG
}

# sleeping to gather some steady-state metrics, pre-test
long_sleep

# set the number of nodes to label based on environment selected
if [[ "$ENVIRONMENT" == "alderaan" ]]; then
	LABEL_COUNT=2
else
	LABEL_COUNT=4
fi

# label the core nodes when using Alderaan env
if [[ "$ENVIRONMENT" == "alderaan" ]]; then
	for compute in $(oc get nodes -l "$CORE_COMPUTE_LABEL" -o json | jq '.items[].metadata.name'); do
        	compute=$(echo $compute | sed "s/\"//g")
        	CORE_NODES[${#CORE_NODES[@]}]=$compute
        	oc label node $compute "$TEST_LABEL"
	done
fi

# pick two random app nodes and label them
for app_node in $(oc get nodes -l "$LABEL" -o json | jq '.items[].metadata.name'); do
	app_node=$(echo $app_node | sed "s/\"//g")
	if [[ "$ENVIRONMENT" == "alderaan" ]]; then
		if ! ($(echo ${CORE_NODES[@]} | grep -q -w $app_node)); then
			NODE_COUNT=$(( NODE_COUNT+1 ))
			oc label node $app_node "$TEST_LABEL"
		fi
	else
		NODE_COUNT=$(( NODE_COUNT+1 ))
		oc label node $app_node "$TEST_LABEL"
	fi
	if [[ $NODE_COUNT -ge $LABEL_COUNT  ]]; then
		break
	fi
done

# Get the pod count on the labeled nodes
for node in $(oc get nodes -l="nodevertical=true" | awk 'NR > 1 {print $1}'); do
	pods_running=$(oc describe node $node | grep -w "Non-terminated \Pods:" | awk  '{print $3}' | sed "s/(//g")
	pod_count=$(( pod_count+pods_running ))
done
total_pod_count=$(( 1000-pod_count ))

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
