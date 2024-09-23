#/!/bin/bash -x
################################################
## Auth=mifiedle@redhat.com qili@redhat.com lhorsley@redhat.com
## Desription: Time how long it takes to scale up to from 500 to 2000 pods with and without the networkpolicy 
## Note: The scale up time with the networkpolicy in place will be more than without, but it should not be an order of magnitude difference.	
## Polarion test case: OCP-41535 - NetworkPolicy scalability - 2000 pods per namespace using customer network policy	
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-41535
## Cluster config: Cluster needed in AWS EC2 (m5.2xlarge or equivalent) with 12 worker nodes
## Related bug: https://bugzilla.redhat.com/show_bug.cgi?id=1950283
## kube-burner config: perfscale_regerssion_ci/kubeburner-object-templates/scaling-network-policy-deployment.yml
## 					   perfscale_regerssion_ci/kubeburner-object-templates/scaling-no-network-policy-deployment.yml
################################################ 
source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source ../common.sh
source network_policy_scalability_env.sh

pass_case=0
workload_template_list=("${DIR}/../../kubeburner-object-templates/scaling-network-policy-config.yaml" "${DIR}/../../kubeburner-object-templates/scaling-no-network-policy-config.yaml")
pod_scale_max=2000
kube_burner_job_list=("np-issue-test" "no-np-issue-test")
final_time_list=()
deny_network_policy="${DIR}/../../content/deny_network_traffic_policy.yaml"
deny_traffic_code=000
return_traffic_code=200


echo "======Use kube-burner to load the cluster with test objects======"
length=${#kube_burner_job_list[@]}
for ((i = 0; i < $length; i++));
do
    export WORKLOAD_TEMPLATE=${workload_template_list[$i]}
    export NAME=${kube_burner_job_list[$i]}
    export NAMESPACE=${kube_burner_job_list[$i]}
    deployment_name=${kube_burner_job_list[$i]}
    scale_up=0

    echo "Load objects for ${kube_burner_job_list[$i]}..."
    run_workload
    echo "Starting scale-up test for ${kube_burner_job_list[$i]}..."
    oc scale --replicas $pod_scale_max deployment $deployment_name -n ${NAMESPACE}; start_time=`date +%s`
    echo "start time: $start_time"
    scale_up=$(oc get deployment $deployment_name --no-headers -n ${NAMESPACE} | awk -F ' {1,}' '{print $4}')
    check_deployment_pod_scale ${NAMESPACE} $deployment_name $scale_up $pod_scale_max
    end_time=`date +%s`
    echo "end time: $end_time"
    final_time=$((end_time - start_time))
    echo "execution time for test ${kube_burner_job_list[$i]}: $final_time s."
    final_time_list+=($final_time)
    # delete the test objects to release more resource for the next test
    if (($(($i+1)) != $length)); then
        delete_project_by_label kube-burner-job
    fi
    sleep 1
    echo "=========================================================================="
done

sleep 5

pod_name=$(oc get po -n ${NAMESPACE} --no-headers | head -n 1 | awk '{print $1}')
pod_ip=$(oc get po $pod_name -n  ${NAMESPACE} --output jsonpath='{.status.podIP}')
apiserver_pod=$(oc get po -n openshift-oauth-apiserver --no-headers | head -n 1 | awk '{print $1}')

echo "Starting test to deny network traffic in the namespace ${NAMESPACE}..."
oc apply -f $deny_network_policy -n ${NAMESPACE}
deny_time_start=`date +%s`
check_http_code $deny_traffic_code $pod_ip $apiserver_pod
deny_time_end=`date +%s`
deny_final_time=$((deny_time_end - deny_time_start))
echo "Time taken for deny network policy to become active: $deny_final_time s"

sleep 1

echo "Starting test to allow network traffic in the namespace ${NAMESPACE}..."
oc delete networkpolicy deny-by-default -n ${NAMESPACE}
return_traffic_start=`date +%s`
check_http_code $return_traffic_code $pod_ip $apiserver_pod
return_traffic_end=`date +%s`
return_traffic_final_time=$((return_traffic_end - return_traffic_start))
echo "Time taken for deny network policy to become inactive: $return_traffic_final_time s"

echo "=========================================================================="


final_time_np=${final_time_list[0]}
final_time_no_np=${final_time_list[1]}
policy_no_policy_difference=$(calculate_difference ${final_time_np} ${final_time_no_np})

if [[ ( $final_time_np -le 120 ) &&  ( $final_time_no_np -le 120 ) && ( $policy_no_policy_difference -le 10 ) ]]; then
    echo "PASS: test time to scale from 500 to 2000 pods with network policy ${final_time_np}s <= 120 s (2 minutes)."
    echo "PASS: test time to scale from 500 to 2000 pods without network policy ${final_time_no_np}s <= 120 s (2 minutes)."
    echo "PASS: Difference in test times to scale from 500 to 2000 pods (between with and without network policy) ${policy_no_policy_difference}s <= 10 s."
    ((++pass_case))
else
    echo "FAIL: Test time to scale from 500 to 2000 pods with network policy: ${final_time_np}s should be <= 120 s (2 minutes)."
    echo "FAIL: Test time to scale from 500 to 2000 pods without network policy ${final_time_no_np}s should be <= 120 s (2 minutes)."
    echo "FAIL: Difference in test times to scale from 500 to 2000 pods (between with and without network policy): ${policy_no_policy_difference}s should be <= 10 s."
fi

if [[ ( $deny_final_time -le 10 ) && ( $return_traffic_final_time -le 10 ) ]]; then
    echo "PASS: Time taken for deny network policy to become active: ${deny_final_time}s <= 10 s."
    echo "PASS: Time taken for deny network policy to become inactive: ${return_traffic_final_time}s <= 10 s."
    ((++pass_case))
else
    echo "FAIL: Time taken for deny network policy to become active: ${deny_final_time}s should be <= 10 s."
    echo "FAIL: Time taken for deny network policy to become inactive: ${return_traffic_final_time} s should be <= 10 s."
fi

echo ""
echo "======Final test result======"

if [[ $pass_case -eq 2 ]]; then
    echo -e "\nOverall NetworkPolicy scalability - using customer network policy Testcase result: PASS"
    echo "======Clean up test environment======"
    echo "Deleting test objects"
    delete_project_by_label kube-burner-job
    exit 0
else
    echo -e "\nOverall NetworkPolicy scalability - using customer network policy Testcase result: FAIL"
    echo "Please debug. When debugging is complete, delete all projects using 'oc delete projects -l kube-burner-job'"
    exit 1
fi