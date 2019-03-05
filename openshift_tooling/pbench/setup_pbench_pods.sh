#!/bin/bash

cleanup_wait_time=$1

if [[ -z $cleanup_wait_time ]]; then
	cleanup_wait_time=10
fi

# Check for kubeconfig
if [[ ! -s $HOME/.kube/config ]]; then
	echo "cannot find kube config in the home directory, please check"
	exit 1
fi

# Check if oc client is installed
which oc &>/dev/null
echo "Checking if oc client is installed"
if [[ $? != 0 ]]; then
	echo "oc client is not installed"
	echo "installing oc client"
 	curl -L https://github.com/openshift/origin/releases/download/v1.2.1/openshift-origin-client-tools-v1.2.1-5e723f6-linux-64bit.tar.gz | tar -zx && \
    	mv openshift*/oc /usr/local/bin && \
	rm -rf openshift-origin-client-tools-*
else
	echo "oc client already present"
fi

status_check_timeout=600
# pod status check
function pod_status_check() {
	namespace=$1
	counter=1
	echo "checking the pod status"
	pod_count=$(oc get pods --namespace=$namespace | awk 'NR > 1 {print $1}' | wc -l)
	# make sure the nodes are labeled
	labeled_node_count=$(oc get nodes -l pbench_role=agent | awk 'NR > 1 {print $1}'| wc -l)
	if [[ $pod_count != 0 ]] && [[ $labeled_node_count != 0 ]]; then
		for pod in $(oc get pods --namespace=$namespace | awk 'NR > 1 {print $1}'); do
        		while [ $(oc --namespace=$namespace get pods $pod -o json | jq -r ".status.phase") != "Running" ]; do
        			sleep 1
				counter=$((counter+1))
				if [[ $counter > $status_check_timeout ]]; then
					echo "$pod is not in running state after waiting for $counter seconds, please check the pod logs and events"
					exit 1
				fi
        		done
        		echo "$pod is up and running"
		done
		echo "All the pods in $namespace namespace are up and running"
	else
		echo "There are $pod_count pods deployed in the $namespace namespace. This script expects pbench_role=agent label on the nodes, please check the node labels"
		exit 1
	fi
}

function setup_jq() {
	echo "Checking if jq is installed"
	which jq &>/dev/null
	if [[ $? != 0 ]]; then
		echo "jq not installed"
		echo "Downloading jq"
		if [[ $(awk -F= '/^NAME/{print $2}' /etc/os-release) == "Fedora" ]]; then
			dnf install -y jq &>/dev/null
		elif [[ $(awk -F= '/^NAME/{print $2}' /etc/os-release | grep "Red Hat") ]]; then
			yum install -y jq &>/dev/null
		else
			echo "Not able to install jq"
			exit 1
		fi
		echo "jq installed successfully"
	else
		echo "jq already installed"
	fi
}


function short_sleep() {
        sleep $cleanup_wait_time
}

# cleanup deamonset if already exists
function cleanup() {
	# pbench cleanup
	oc delete serviceaccount useroot -n pbench
	oc delete -f openshift_templates/performance_monitoring/pbench/pbench-agent-daemonset.yml -n pbench
	oc delete -f openshift_templates/performance_monitoring/pbench/pbench-namespace.yml -n pbench

	# waiting for the pods to get terminated
	echo "Waiting for $cleanup_wait_time seconds for namespaces and pods cleanup" 
	short_sleep
}

# Create a service account and add it to the privileged scc
function create_service_account() {
        oc create serviceaccount useroot -n pbench
        oc adm policy add-scc-to-user privileged -z useroot -n pbench
}
	
pushd /root/svt

# Setup pbench-agent in pbench namespace
oc project pbench &>/dev/null
if [[ $? == 0 ]]; then
	echo "Looks like there is already a project named pbench"
	echo "Deleting the pbench project"
	cleanup
fi
oc create -f openshift_templates/performance_monitoring/pbench/pbench-namespace.yml
oc project pbench
create_service_account

# Create pbench-agent pods and patch it
oc create -f openshift_templates/performance_monitoring/pbench/pbench-agent-daemonset.yml -n pbench
oc patch daemonset pbench-agent --patch \ '{"spec":{"template":{"spec":{"serviceAccountName": "useroot"}}}}' -n pbench

popd

# Setup jq if not already installed
# jq is already baked in case you are using the image generated using image provisioner
setup_jq

# Check if the pbench pods are running
short_sleep
pod_status_check pbench
