#/!/bin/bash
################################################
## Auth=prubenda@redhat.com lhorsley@redhat.com
## Desription: Script for creating large number of secrets
## Polarion test case: OCP-65206
## https://polarion.engineering.redhat.com/polarion/redirect/project/OSE/workitem?id=OCP-65206
## Cluster config: 3 master (m5.2xlarge or equivalent) with 3 worker
## kube-burner config: perfscale_regerssion_ci/kubeburner-object-templates/secret-projects-config.yml
## PARAMETERS: number of JOB_ITERATION
################################################ 

source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source ../common.sh
source large_secret_list_env.sh

echo "job iterations $JOB_ITERATION $PARAMETERS"
echo "======Use kube-burner to load the cluster with test objects======"
run_workload

secret_count=$(oc get secrets -A -l test=listobject --no-headers | wc -l)
expected_secrets=$(( $JOB_ITERATION * $SECRET_REPLICAS ))
echo -e "\nTotal number of ${NAMESPACE} namespaces created: ${TOTAL_CLUSTERPROJECTS}"

if [[ $expected_secrets -eq $secret_count ]]; then
  echo "======PASS======"
  exit 0
else
  echo "======FAIL======"
  echo "Please debug, when done, delete all projects using 'oc delete project -l kube-burner-job=$NAMESPACE'"
  oc get secrets -A -l test=listobject --no-headers -v9
  exit 1
fi