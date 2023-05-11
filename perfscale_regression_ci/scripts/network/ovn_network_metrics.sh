#/!/bin/bash
################################################
## Auth=lhorsley@redhat.com 
## Desription: Script for checking ovnkube_master_sync_duration_seconds and ovnkube_master_pod_event_latency_seconds_bucket metrics on an OVN cluster
## Polarion test case: 
## Bug related: https://bugzilla.redhat.com/show_bug.cgi?id=1752636
## Cluster config: 3 master (m5.2xlarge or equivalent) with 40 workers
## kube-burner config: perfscale_regerssion_ci/kubeburner-object-templates/ovn-network-metrics-config.yaml
## network-policy config: perfscale_regerssion_ci/content/ovn_metrics_network_policy.yaml
##
##
## Setup:
## Step 1. Edit the ovn-kube-master daemonset
## oc edit ds/ovnkube-master -n openshift-ovn-kubernetes
## Search for --acl-logging-rate-limit (add the flag --metrics-enable-scale after --acl-logging-rate-limit)
## Save the changes.
## 
## Step 2. Stop all the managing operators (to stop the managing operators that will try to revert the changes)
## oc scale deployment cluster-version-operator -n openshift-cluster-version --replicas=0
## oc scale deployment network-operator -n openshift-network-operator --replicas=0
## 
## The master pods in the openshift-ovn-kubernetes namespace will restart. Once the pods have restarted, execute the test.
################################################ 

source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source ../common.sh
source ovn_network_metrics_env.sh

set -x
pass_fail=0
network_namespace="openshift-ovn-kubernetes"
i=0
sync_duration_seconds_metrics=""

# Create 15 namespaces. Each namespace will have 1 network policy and 500 pods
echo "======Use kube-burner to load the cluster with test objects======"
run_workload


# Get the master pods in the openshift-ovn-kubernetes namespace
ovn_network_master_pods=$(oc get pods -n $network_namespace -o name | grep master | grep -v controller)

echo $ovn_network_master_pods

ovn_network_master_pods_arr=($ovn_network_master_pods)


# Send a request to each master pod. If the metrics are not returned, check the next pod.
# If the metrics for ovnkube_master_sync_duration_seconds are returned, get the ovnkube_master_pod_event_latency_seconds_bucket metrics.
while [[ ( $i -lt 3 ) && ( -z $sync_duration_seconds_metrics) ]];
do
    # The command "set +e" allows the script to execute even though the exit code is 28.
    set +e
    echo "checking ${ovn_network_master_pods_arr[i]}"
    sync_duration_seconds_metrics=$(eval "oc exec ${ovn_network_master_pods_arr[i]} -n $network_namespace -c northd -- curl -s "127.0.0.1:29102/metrics" | grep ovnkube_master_sync_duration_seconds | grep -v HELP | grep -v TYPE")
    if [[ -n "$sync_duration_seconds_metrics" ]]; then
        pod_event_latency_seconds_bucket_metrics=$(eval "oc exec ${ovn_network_master_pods_arr[i]} -n $network_namespace -c northd -- curl -s "127.0.0.1:29102/metrics" | grep ovnkube_master_pod_event_latency_seconds_bucket")
    fi
    (( i++ ))
done

set -e
set +x

if [[ ( -n "$sync_duration_seconds_metrics" ) && ( -n "$pod_event_latency_seconds_bucket_metrics" ) ]]; then
    pass_fail=1
    echo "Metrics collected"
    echo "sync_duration_seconds metrics"
    echo "metric is $sync_duration_seconds_metrics"
    echo " "
    echo "======================================================================"
    echo "pod_event_latency_seconds_bucket metrics"
    echo "metric is $pod_event_latency_seconds_bucket_metrics"
fi

echo "======Final test result======"

if [[ $pass_fail -eq 1 ]]; then
	echo -e "\nOVN metrics Testcase result:  PASS"
    echo "Before deleteing the projects, verify the metrics in the console (go to Observe > Metrics)"
    echo "Search for 'ovnkube_master_sync_duration_seconds' and 'ovnkube_master_pod_event_latency_seconds_bucket'"
  	echo "Delete all projects using 'oc delete project -l kube-burner-job=${NAME}'"
	exit 0
else
	echo -e "\nOVN metrics Testcase result:  FAIL"
 	 echo "Please debug. When debugging is complete, delete all projects using 'oc delete project -l kube-burner-job=${NAME}'"
	exit 1
fi