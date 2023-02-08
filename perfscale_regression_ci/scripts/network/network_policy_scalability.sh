#/!/bin/bash
################################################
## Auth=mifiedle@redhat.com lhorsley@redhat.com
## Desription: On a 10 node OVN cluster, time how long it takes to scale up to 2000 pods with and without the networkpolicy 
## Note: The scale up time with the networkpolicy in place will be more than without, but it should not be an order of magnitude difference.	
## This automated test does not cover step 5.1 - 5.4 in the Polarian test case
## Polarion test case: OCP-41535 - NetworkPolicy scalability - 2000 pods per namespace using customer network policy	
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-41535
## Cluster config: Cluster needed in AWS EC2 (m5.2xlarge or equivalent) with 20 worker nodes
## Related bug: https://bugzilla.redhat.com/show_bug.cgi?id=1950283
## kube-burner config: perfscale_regerssion_ci/kubeburner-object-templates/node-affinity-anti-affinity-config.yml
################################################ 

source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source ../common.sh
source network_policy_scalability_env.sh

pass_fail=0
workload_template_list=("${DIR}/../../kubeburner-object-templates/scaling-network-policy-config.yaml" "${DIR}/../../kubeburner-object-templates/scaling-no-network-policy-config.yaml")
pod_scale_max=2000
kube_burner_job_list=("np-issue-test" "no-np-issue-test")
final_time_list=()

echo "======Use kube-burner to load the cluster with test objects======"

for ((i = 0; i < 2; i++));
do
    export WORKLOAD_TEMPLATE=${workload_template_list[$i]}
    export NAME=${kube_burner_job_list[$i]}
    export NAMESPACE=${kube_burner_job_list[$i]}
    deployment_name=${kube_burner_job_list[$i]}
    scale_up=0

    echo "Starting scale-up test for ${kube_burner_job_list[$i]}..."
    run_workload
    oc scale --replicas $pod_scale_max deployment $deployment_name -n ${NAMESPACE}; start_time=`date +%s`
    echo "start time: $start_time"
    scale_up=$(oc get deployment $deployment_name --no-headers -n ${NAMESPACE} | awk -F ' {1,}' '{print $4}')
    check_deployment_pod_scale ${NAMESPACE} $deployment_name $scale_up $pod_scale_max
    end_time=`date +%s`
    echo "end time: $end_time"
    final_time=$((end_time - start_time))
    echo "execution time for test ${kube_burner_job_list[$i]}: $final_time s."
    final_time_list+=($final_time)
    echo "=========================================================================="
done

final_time_np=${final_time_list[0]}
final_time_no_np=${final_time_list[1]}

echo "execution time with network policy was $final_time_np s."
echo "execution time without network policy was $final_time_no_np s."


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

if [[ $pass_fail -eq 2 ]]; then
	echo -e "\nOverall NetworkPolicy scalability - using customer network policy Testcase result:  PASS"
  	echo "======Clean up test environment======"
	# # delete projects:
  	# ######### Clean up: delete projects and wait until all projects and pods are gone
  	echo "Deleting test objects"
	delete_project_by_label kube-burner-job=${kube_burner_job_list[0]}
    delete_project_by_label kube-burner-job=${kube_burner_job_list[1]}
	exit 0
else
	echo -e "\nOverall NetworkPolicy scalability - using customer network policy Testcase result:  FAIL"
 	 echo "Please debug. When debugging is complete, delete all projects using 'oc delete project -l kube-burner-job=${kube_burner_job_list[0]}' and 'oc delete project -l kube-burner-job=${kube_burner_job_list[1]}'"
	exit 1
fi