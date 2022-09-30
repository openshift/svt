#/!/bin/bash
################################################
## Auth=prubenda@redhat.com qili@redhat.com
## Desription: Script for creating pause deployments and adding network policies
## Polarion test case: OCP-26279 - [BZ 1752636] Networkpolicy should be applied for large namespaces
## https://polarion.engineering.redhat.com/polarion/redirect/project/OSE/workitem?id=OCP-26279
## Bug related: https://bugzilla.redhat.com/show_bug.cgi?id=1752636
## Cluster config: 3 master (m5.2xlarge or equivalent) with 27 worker
## kube-burner config: perfscale_regerssion_ci/kubeburner-object-templates/large-network-policy.yaml
## network-policy config: perfscale_regerssion_ci/content/allow_default_network_policy.yaml
## PARAMETERS: number of JOB_ITERATION
################################################ 

source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source ../common.sh
source large_network_policy_env.sh

# If PARAMETERS is set from upstream ci, overwirte JOB_ITERATION
export JOB_ITERATION=${PARAMETERS:-5000}

echo "======Use kube-burner to load the cluster with test objects======"
run_workload

echo "======Apply network policy to all namespaces======"
for i in $(oc get projects | grep large-network-policy | grep -Eo 'large-network-policy\S*');
do
  echo "$i"
  oc create -f ${NETWORK_POLICY} -n "$i"
done

echo "======Verify there are enough policies in flow======"
network_namespace="openshift-sdn"
container_name="sdn"
sdn_project_count=$(oc get projects | grep sdn | wc -l | xargs)
# Comment out the below lines because line 42 only work on OVN
# echo "sdn count $sdn_project_count"
# if [[ $sdn_project_count -ne 1 ]]; then
#   network_namespace="openshift-ovn-kubernetes"
#   container_name="ovnkube-node"
# fi

network_pods=$(oc get pods -n $network_namespace -o name)

echo $network_pods

total_policies=0
for pod in $network_pods;
do
# The below command can only be run on SDN, not workable on OVN
# On ovn I got this "ovs-ofctl: br0 is not a bridge or a socket"
   count=$(oc exec $pod -n $network_namespace -c $container_name -- ovs-ofctl dump-flows br0 -O openflow13 | grep table=80 | wc -l | xargs)
   echo "$count"
   total_policies=$(($total_policies + $count))
done

echo "======Total flows in pods $total_policies======"

if [[ $total_policies -ge $JOB_ITERATION ]]; then
  echo "======PASS======"
  echo "Deleting test objects"
  delete_project_by_label kube-burner-job=$NAME
  exit 0
else
  echo "======FAIL======"
  echo "Not enough policies in flow, see https://bugzilla.redhat.com/show_bug.cgi?id=1752636#c61."
  echo "Please debug, when done, delete all projects using 'oc delete project -l kube-burner-job=large-network-policy'"
  exit 1
fi
