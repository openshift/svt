#/!/bin/bash
################################################
## Auth=mifiedle@redhat.com lhorsley@redhat.com
## Desription: On a 10 node OVN cluster, time how long it takes to scale up to 2000 pods with and without the networkpolicy 
## Note: The scale up time with the networkpolicy in place will be more than without, but it should not be an order of magnitude difference.	
## This automated test does not cover step 5.1 - 5.4 in the Polarian test case
## Polarion test case: OCP-41535 - NetworkPolicy scalability - 2000 pods per namespace using customer network policy	
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-41535
## Cluster config: Cluster needed in AWS EC2 (m5.xlarge, 3 master/etcd, 3 worker/compute nodes)
## kube-burner config: perfscale_regerssion_ci/kubeburner-object-templates/node-affinity-anti-affinity-config.yml
################################################ 

source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source ../common.sh
source network_policy_scalability_env.sh

pod_scale_max=2000
pod_scale_min=500
pass_fail=0
project_name="np-issue-test"
deployment_name=$project_name
export NAME=$project_name
export NAMESPACE=$project_name


project_label="test=np-issue-test"



echo "Create and label new project"
prepare_project ${NAMESPACE} $project_label


echo "Applying netowrk policy..."
oc apply -f  ${NETWORK_POLICY} -n ${NAMESPACE}
echo ""

echo "Starting scale-up test with network policy..."
echo ""

# SCALE UP DEPLOYMENT
scale_w_np_start_time=`date +%s`

echo "======Use kube-burner to load the cluster with test objects======"
run_workload

scale_up_np=$(oc get deployment $deployment_name --no-headers -n ${NAMESPACE} | awk -F ' {1,}' '{print $4}')

#scale_up_np=$(oc get pods -n ${NAMESPACE} --no-headers | wc -l)

echo "start time: $scale_w_np_start_time"
check_deployment_pod_scale ${NAMESPACE} $deployment_name $scale_up_np $pod_scale_max
scale_w_np_end_time=`date +%s`
echo "end time: $scale_w_np_end_time"

final_time_np=$((scale_w_np_end_time - scale_w_np_start_time))
echo "execution time with network policy was $final_time_np s."

echo "=========================================================================="
echo ""

# #DELETE NETWORK POLICY
echo "Deleting network policy..."
oc get networkpolicy -n ${NAMESPACE} --no-headers | awk {'print $1'} | xargs oc delete networkpolicy -n ${NAMESPACE}
echo ""

# SCALE DOWN DEPLOYMENT
echo "Scaling down the deployment..."

scale_down=$(oc get deployment $deployment_name --no-headers -n ${NAMESPACE} | awk -F ' {1,}' '{print $4}')
echo ""

oc scale --replicas $pod_scale_min deployment $deployment_name -n ${NAMESPACE}

oc get deployment $deployment_name  -n ${NAMESPACE}

check_deployment_pod_scale ${NAMESPACE} $deployment_name $scale_down $pod_scale_min
echo ""

echo "Phew! Let me catch my breath for a second..."
sleep 5

echo "=========================================================================="
echo ""


# SCALE UP DEPLOYMENT
echo "Starting scale-up test without network policy..."

scale_up_no_np=$(oc get deployment $deployment_name --no-headers -n ${NAMESPACE} | awk -F ' {1,}' '{print $4}')
oc scale --replicas $pod_scale_max deployment $deployment_name -n ${NAMESPACE}; start_time=`date +%s`

echo "start time: $start_time"
check_deployment_pod_scale ${NAMESPACE} $deployment_name $scale_up_no_np $pod_scale_max

end_time=`date +%s`
echo "end time: $end_time"

final_time_no_np=$((end_time - start_time))
echo "execution time without network policy was $final_time_no_np s."

echo "=========================================================================="
echo ""

echo "execution time with network policy was $final_time_np s."
echo "execution time without network policy was $final_time_no_np s."



if [[ ( $final_time_np -ge $final_time_no_np ) ]]; then
	echo "Expected: test time with network policy > test time without network policy."
	((++pass_fail))
else
	echo "Expected: test time with network policy < test time without network policy."
fi


if [[ ( $final_time_np -le 120 ) ]]; then
	echo "Expected: test time with network policy <= 120 seconds (2 minutes)."
	((++pass_fail))
else
	echo "Expected: test time with network policy >= 120 seconds (2 minutes)."
fi


if [[ ( $final_time_no_np -le 120 ) ]]; then
	echo "Expected: test time without network policy <= 120 seconds (2 minutes)."
	((++pass_fail))
else
	echo "Expected: test time without network policy >= 120 seconds (2 minutes)."
fi


echo ""
echo "======Final test result======"

if [[ $pass_fail -eq 3 ]]; then
	echo -e "\nOverall NetworkPolicy scalability - using customer network policy Testcase result:  PASS"
  	echo "======Clean up test environment======"
	# # delete projects:
  	# ######### Clean up: delete projects and wait until all projects and pods are gone
  	echo "Deleting test objects"
	delete_project_by_label $project_label
	exit 0
else
	echo -e "\nOverall NetworkPolicy scalability - using customer network policy Testcase result:  FAIL"
 	 echo "Please debug. When debugging is complete, delete all projects using 'oc delete project -l $project_label"
	exit 1
fi