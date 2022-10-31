#/!/bin/bash
################################################
## Auth=prubenda@redhat.com lhorsley@redhat.com
## Desription: This testcase tests descheduling pods in a deployment at scale	
## Polarion test case: OCP-44241 - Descheduler - Validate Descheduling Pods in a Deployment at scale		
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-44241
## Cluster config: Cluster needed in AWS EC2 (at least m6i.large, 3 master/etcd, 3 worker/compute nodes)
################################################ 
source ./common_func.sh
source ../../common.sh


function prepare_project() {
  oc new-project $name
  oc label namespace $name $label
}

name="perf-test-pod-descheduler"
label="test=$name"
i=0
last_worker=""
first_worker=""
middle_worker=""
scale_num=190
pass_or_fail=1


echo "Create and label new project"
prepare_project $name $label


echo "Prepare worker nodes"
worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker= -o name)


for worker in ${worker_nodes}; do
  if [[ $i -eq 0 ]]; then
    first_worker=$worker
  elif [[ $i -eq 1 ]]; then
    oc adm cordon $worker
    middle_worker=$worker
  elif [[ $i -eq 2 ]]; then
    oc adm cordon $worker
    last_worker=$worker
  fi
  i=$((i + 1))
done

echo "Deploy pods"
### creates hello-1 pods
oc create deployment hello-first --image=gcr.io/google-containers/pause-amd64:3.0
# oc edit dc hello and change the replica to 12
oc scale --replicas=$scale_num deployment/hello-first

wait_for_pod_creation hello-first

oc adm cordon $first_worker
oc adm uncordon $middle_worker

# create hello pods
oc create deployment hello-second --image=gcr.io/google-containers/pause-amd64:3.0
oc scale --replicas=$scale_num deployment/hello-second
wait_for_pod_creation hello-second

oc adm cordon $middle_worker
oc adm uncordon $last_worker


# create hello pods
oc create deployment hello-third --image=gcr.io/google-containers/pause-amd64:3.0
oc scale --replicas=$scale_num deployment/hello-third

#wait till pods are running
wait_for_pod_creation hello-third

uncordon_all_nodes

wait_for_descheduler_to_run


echo "Check for pods eviction"
get_descheduler_evicted

deployment_list=('hello-first' 'hello-second' 'hello-third')
for deployment in "${deployment_list[@]}"; do
  for worker in ${worker_nodes}; do
    pod_count=$(get_pod_count $deployment $worker)
    echo "$pod_count $deployment pods on $worker "
    if [[ $pod_count -eq 190 ]]; then
      pass_or_fail=0
    fi
  done
  echo "\n"
done

oc project default

echo "======Final test result======"
if [[ ${pass_or_fail} == 1 ]]; then
  echo -e "\nDescheduler - Validate Descheduling Pods in a Deployment at scale Testcase result:  PASS"
  echo "======Clean up test environment======"
  # # delete projects:
  # ######### Clean up: delete projects and wait until all projects and pods are gone
  echo "Deleting test objects"
  delete_project_by_label $label

  exit 0
else
  echo -e "\nDescheduler - Validate Descheduling Pods in a Deployment at scale Testcase result:  FAIL"
  echo "Please debug. When debugging is complete, delete all projects using 'oc delete project $name' "
  exit 1
fi