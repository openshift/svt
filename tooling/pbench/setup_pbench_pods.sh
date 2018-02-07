#!/bin/bash

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

status_check_timeout=20
# pod status check
function pod_status_check() {
	namespace=$1
	counter=1
	echo "checking the pod status"
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
	echo "All the pods in $namespace are up and running"
}

function setup_jq() {
	echo "Checking if jq is installed"
	if ! jq &> /dev/null; then
		echo "jq not installed"
		echo "Downloading jq"
		if [[ $(awk -F= '/^NAME/{print $2}' /etc/os-release) == "Fedora" ]]; then
			dnf install -y jq
		elif [[ $(awk -F= '/^NAME/{print $2}' /etc/os-release | grep "Red Hat") ]]; then
			yum install -y jq
		else
			echo "Not able to install jq"
			exit 1
		fi
		echo "jq installed successfully"
	else
		echo "jq already present"
	fi
}


function short_sleep() {
        sleep 20
}

# cleanup deamonset if already exists
function cleanup() {
	# pbench cleanup
	oc delete serviceaccount useroot
	oc delete -f openshift_templates/performance_monitoring/pbench/pbench-agent-daemonset.yml
	oc delete -f openshift_templates/performance_monitoring/pbench/pbench-namespace.yml

	# sleep for 20 seconds for the pods to get terminated
	echo "Waiting for 20 seconds for pods to get terminated, namespace to be deleted if exists" 
	short_sleep
}

# Create a service account and add it to the privileged scc
function create_service_account() {
        oc create serviceaccount useroot
        oc adm policy add-scc-to-user privileged -z useroot
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
create_service_account

# Create pbench-agent pods and patch it
oc create -f openshift_templates/performance_monitoring/pbench/pbench-agent-daemonset.yml
oc patch daemonset pbench-agent --patch \ '{"spec":{"template":{"spec":{"serviceAccountName": "useroot"}}}}'

popd

# Setup jq if not already installed
# jq is already baked in case you are using the image generated using image procisioner
setup_jq

# Check if the pbench pods are running
short_sleep
pod_status_check pbench
