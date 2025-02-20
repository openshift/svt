#/!/bin/bash
################################################
## Auth=prubenda@redhat.com qili@redhat.com
## Desription: Script for creating pause deployments and adding network policies
## Polarion test case: OCP-9461
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-25937&revision=13305128
## Cluster config: 3 master (m5.2xlarge or equivalent) with 3 worker
## kube-burner config: perfscale_regerssion_ci/kubeburner-object-templates/loaded-projects-config.yml
## PARAMETERS: number of JOB_ITERATION
################################################ 

source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source ../common.sh
source etcd_load_env.sh

# If PARAMETERS is set from upstream ci, overwirte JOB_ITERATION
export JOB_ITERATION=${PARAMETERS:-1}

echo "job iterations $JOB_ITERATION $PARAMETERS"
echo "======Use kube-burner to load the cluster with test objects======"
run_workload

TOTAL_CLUSTERPROJECTS=$(oc get projects | grep -c ${NAMESPACE})
echo -e "\nTotal number of ${NAMESPACE} namespaces created: ${TOTAL_CLUSTERPROJECTS}"

if [[ $TOTAL_CLUSTERPROJECTS -ge $JOB_ITERATION ]]; then

  cd ../encryption
  ./enable_encryption.sh
  echo "======PASS======"
  exit 0
else
  echo "======FAIL======"
  echo "Please debug, when done, delete all projects using 'oc delete project -l kube-burner-job=$NAMESPACE'"
  exit 1
fi

