#/!/bin/bash
################################################
## Auth=prubenda@redhat.com lhorsley@redhat.com
## Desription: This testcase tests Pod Affinity and anti-affinity as we approach pod capacity on compute nodes.
## Polarion test case: OCP-18083 - NextGen Pod scheduler at capacity with Pod Affinity and Anti-Affinity rules	
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-18083
## Cluster config: Cluster needed in AWS EC2 (m5.xlarge, 3 master/etcd, 3 worker/compute nodes)
## kube-burner config: perfscale_regerssion_ci/kubeburner-object-templates/pod-affinity-anti-affinity-config.yml
################################################ 


source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source ../common.sh
source pod-affinity-anti-affinity_env.sh


export POD_ANTI_AFFINITY_JOB_ITERATION=${POD_ANTI_AFFINITY_JOB_ITERATION:-190}
export POD_AFFINITY_JOB_ITERATION=${POD_AFFINITY_JOB_ITERATION:-190}

function wait_for_running() {
  counter=0
  while true; do
    all_running=1

    oc get pods -n s1-proj -o wide
    RUNNING=$(oc get pods -n s1-proj)
    echo "Pod status in namespace s1-proj: ${RUNNING}"
    if [[ $RUNNING =~ Running ]]; then
      oc get pods -n s1-proj -o wide
      echo "Pod s1 in namespace s1-proj is now Running"
    else
      all_running=0
      echo "Pod s1 in namespace s1-proj is still not Running"
    fi

    if [ $all_running -eq 1 ]; then
      break
    fi

    if [[ $counter == 10 ]]; then
      echo "s1 pod failed to get into Running state"
      error_exit "s1 pod failed to get into Running state"
    fi

    (( ++counter ))
    sleep 15
  done

}


# Output some general information about the test environment
date
uname -a
oc get clusterversion
oc version
oc get node --show-labels
oc describe node | grep Runtime


echo "======Setup/Configuration: Create the s1-proj namespace and the s1-test pod======"

current_date=$(date +%Y-%m-%d-%H%M)
echo "Date timestamp used for s1 pod spec filename: ${current_date}"

worker_nodes=$(oc get nodes -l 'node-role.kubernetes.io/worker=' | awk '{print $1}' | grep -v NAME | xargs)

echo -e "\nWorker  nodes are: $worker_nodes"

oc get nodes -l 'node-role.kubernetes.io/worker='
oc describe nodes -l 'node-role.kubernetes.io/worker='

# Create the yaml file for the pod
echo -e "apiVersion: v1
kind: Pod
metadata:
  name: s1-test-pod
  labels:
    security: s1

spec:
  containers:
  - name: ocp
    image: gcr.io/google-containers/pause-amd64:3.0
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
      runAsNonRoot: true
      runAsUser: 2000
      seccompProfile:
        type: RuntimeDefault
    ports:
    - containerPort: 8080
  dnsPolicy: ClusterFirst
  restartPolicy: Always" > pod-s1-${current_date}.yaml

ls -ltr pod-s1-${current_date}.yaml
cat pod-s1-${current_date}.yaml

# Create a new project
oc new-project s1-proj

# Create/deploy a pod in the new project
oc create -f pod-s1-${current_date}.yaml

oc get pods -n s1-proj -o wide

check_no_error_pods s1-proj

wait_for_running


# Once the pod is running, find it's node
s1pod_node=$(oc get pods -n s1-proj -o wide --no-headers | awk {'print $7}')

echo -e "\nPod s1 was deployed on node ${s1pod_node}"

oc project default


echo "======Use kube-burner to load the cluster with test objects======"
run_workload

echo "======Checking the pods for errors======"

check_no_error_pods $POD_AFFINTIY_NAMESPACE

check_no_error_pods $POD_ANTI_AFFINTIY_NAMESPACE

echo -e "\n============= Summary of pod count with affinity to s1 pod: =================="

s1_affinity_pod_expected=$POD_AFFINITY_JOB_ITERATION
s1_anti_affinity_pod_expected=$POD_ANTI_AFFINITY_JOB_ITERATION



s1_affinity_pod_actual=$(oc get pods -n ${POD_AFFINTIY_NAMESPACE} -o wide | grep ${s1pod_node} | grep Running | wc -l | xargs)
echo -e "\nNumber of pods deployed with pod affinity to pod s1:  ${s1_affinity_pod_actual} , expecting ${s1_affinity_pod_expected} pods"

echo -e "\n============= Summary of pod count with anit-affinity to s1 pod: =================="



s1_anti_affinity_pod_actual=$(oc get pods -n ${POD_ANTI_AFFINTIY_NAMESPACE} -o wide | grep -v ${s1pod_node} | grep Running | wc -l | xargs)
echo -e "\nNumber of pods deployed with pod anti-affinity to pod s1 on nodes other than ${s1pod_node} is : ${s1_anti_affinity_pod_actual} , expecting ${s1_anti_affinity_pod_expected} pods"


echo "======Compare the expected and actual number of pods for each namespace. Get the PASS/FAIL result for each namespace======"
pass_or_fail=0


if [ $s1_affinity_pod_expected == $s1_affinity_pod_actual ]; then
  echo -e "Actual $s1_affinity_pod_expected pods were sucessfully deployed. Node affinity test passed!"
  (( ++pass_or_fail ))
else
  echo -e "Actual $s1_affinity_pod_actual pods deployed does NOT match expected $s1_affinity_pod_expected pods for node affinity test.  Node affinity test failed !"
fi


if [ $s1_anti_affinity_pod_expected == $s1_anti_affinity_pod_actual ]; then
  echo -e "Actual $s1_anti_affinity_pod_expected pods were sucessfully deployed.  Node Anti-affinity test passed!"
  (( ++pass_or_fail ))
else
  echo -e "Actual $s1_anti_affinity_pod_actual pods deployed does NOT match expected $s1_anti_affinity_pod_expected pods for node Anti-affinity test. Node Anti-affinity test failed !"
fi


echo "======Final test result======"
if [[ ${pass_or_fail} == 2 ]]; then
  echo -e "\nOverall Pod Affinity and Anti-affinity Testcase result:  PASS"
  echo "======Clean up test environment======"
  # # delete projects:
  # ######### Clean up: delete projects and wait until all projects and pods are gone
  echo "Deleting test objects"
  delete_project_by_label kube-burner-job=$POD_AFFINTIY_NAME
  delete_project_by_label kube-burner-job=$POD_ANTI_AFFINTIY_NAME
  delete_project_by_label "kubernetes.io/metadata.name=s1-proj"
  rm -f   pod-s1-${current_date}.yaml

  exit 0
else
  echo -e "\nOverall Pod Affinity and Anti-affinity Testcase result:  FAIL"
  echo "Please debug. When debugging is complete, delete all projects using 'oc delete project -l kube-burner-job=$POD_AFFINTIY_NAME' , 'oc delete project -l kube-burner-job=$POD_ANTI_AFFINTIY_NAME' and 'oc delete project -l kubernetes.io/metadata.name=s1-proj'"
  exit 1
fi