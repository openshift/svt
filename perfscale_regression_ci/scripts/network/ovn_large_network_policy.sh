#/!/bin/bash
################################################
## Auth=lhorsley@redhat.com prubenda@redhat.com qili@redhat.com
## Desription: Script for creating pause deployments and adding network policies on an OVN cluster
## This test follows the same format as https://github.com/openshift/svt/blob/master/perfscale_regression_ci/scripts/network/large_network_policy.sh
## Polarion test case: OCP-26279 - [BZ 1752636] Networkpolicy should be applied for large namespaces
## https://polarion.engineering.redhat.com/polarion/redirect/project/OSE/workitem?id=OCP-26279
## Bug related: https://bugzilla.redhat.com/show_bug.cgi?id=1752636
## Cluster config: 3 master (m5.2xlarge or equivalent) with 40 workers
## kube-burner config: perfscale_regerssion_ci/kubeburner-object-templates/ovn-large-network-policy-pause-config.yaml
## network-policy config: perfscale_regerssion_ci/content/ovn-allow_default_network_policy.yaml
## PARAMETERS: number of JOB_ITERATION
################################################ 


source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source ../common.sh
source ovn_large_network_policy_env.sh

# There are different containers for the master and worker nodes.
# ovnkube-master containers
#   * northd
#   * nbdb
#   * kube-rbac-proxy
#   * sbdb
#   * ovnkube-master
#   * ovn-dbchecker

# ovnkube-node containers
#   * ovn-controller
#   * ovn-acl-logging
#   * kube-rbac-proxy
#   * kube-rbac-proxy-ovn-metrics
#   * ovnkube-node - this is the container mentioned in the test case
# 
# Per Nadia's suggestion, here are the tables and priorities for ingress and egress policies
# egress policies: table=22, priority=2001 
# ingress policies: table=44, priority=2001


ingress_table="table=44"
ingress_priority="priority=2001"
network_namespace="openshift-ovn-kubernetes"
container_name="ovnkube-node"

my_total_policies=0
export JOB_ITERATION=${PARAMETERS:-5000}


echo "======Use kube-burner to load the cluster with test objects======"
run_workload

echo "======Apply network policy to all namespaces======"
for i in $(oc get projects | grep ovn-large-network-policy | grep -Eo 'ovn-large-network-policy\S*');
do
  echo "$i"
  oc create -f ${NETWORK_POLICY} -n "$i"
done

sleep 5

echo "======Get the network pods======"
ovn_network_pods=$(oc get pods -n $network_namespace -o name | grep -v controller | grep $container_name)

echo "pods in the $network_namespace namespace"
echo $ovn_network_pods

echo "================================================================================================"
echo ""


# When counting flows on a SDN cluster, you can use the command:
# oc exec $pod -n $network_namespace -c $container_name -- ovs-ofctl dump-flows br0 -O openflow13 | grep table=80 | wc -l | xargs
# However,the following error is displayed on OVN (also, table 80 does not exist in OVN)
#  "ovs-ofctl: br0 is not a bridge or a socket"
# Use "br-int", "table=44", and "priority=2001"
echo "======Count the flows======"
for my_ovn_pod in $ovn_network_pods
do
    my_count=$(oc exec $my_ovn_pod -n $network_namespace -c $container_name -- ovs-ofctl dump-flows br-int -O openflow13 | grep $ingress_table | grep $ingress_priority | wc -l | xargs)
    echo "$my_ovn_pod flows: $my_count"
    my_total_policies=$(($my_total_policies + $my_count))
    
done

echo "TOTAL FLOWS: $my_total_policies"

echo "======Final test result======"

if [[ $my_total_policies -ge $JOB_ITERATION ]]; then
	echo -e "\nOVN large network policy Testcase result:  PASS"
  	echo "======Clean up test environment======"
	# # delete projects:
  	# ######### Clean up: delete projects and wait until all projects and pods are gone
  	echo "Deleting test objects"
	delete_project_by_label kube-burner-job
	exit 0
else
	echo -e "\nOVN large network policy Testcase result:  FAIL"
 	 echo "Please debug. When debugging is complete, delete all projects using 'oc delete project -l kube-burner-job=${NAME}'"
	exit 1
fi
