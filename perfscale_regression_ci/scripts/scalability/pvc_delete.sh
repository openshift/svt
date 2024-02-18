#/!/bin/bash
################################################
## Auth=prubenda@redhat.com qili@redhat.com
## Desription: Script for creating pause deployments and adding network policies
## Polarion test case: OCP-9461
## https://polarion.engineering.redhat.com/polarion/redirect/project/OSE/workitem?id=OCP-9461
## Cluster config: 3 master (m5.2xlarge or equivalent) with 3 worker
## kube-burner config: perfscale_regerssion_ci/kubeburner-object-templates/loaded-projects-config.yml
## PARAMETERS: number of JOB_ITERATION
################################################ 

source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source ../common.sh
source pvc_delete_env.sh

results_file=pvc_delete.out

rm -irf $results_file

export params=(${PARAMETERS:-gcp 3 sk2})
echo "params is $params"

export CLOUD=${params[0]:-"gcp"}
iterations_num=${params[1]:-"3"}
export STORAGE_CLASS=${params[2]:-"sk2"}
pvc_nums=(10 20 30 50 100 200)

function create_sk2_storageclass() {
  echo "find storage class"
  storage_classes=$(oc get storageclass --no-headers -o name)
  sk2_exists=true
  echo "storage classes $storage_classes"
  for storage_class in $storage_classes; do
    if [[ $storage_class =~ "sk2" ]]; then
      sk2_exists=false
      echo "exists"
    fi
  done
  if $sk2_exists; then
    echo "create"
    if [[ $cloud_provider == "azure" ]]; then
      oc create -f ../../kubeburner-object-templates/sk2-pvc/pvc-templates/sk2_azure.yaml
    elif [[ $cloud_provider == "gcp" ]]; then
      echo "create gcp sk2"
      oc create -f ../../kubeburner-object-templates/sk2-pvc/sk2_gcp.yaml
    else
      oc create -f ../../kubeburner-object-templates/sk2-pvc/sk2.yaml
    fi
  fi
}

create_sk2_storageclass

for pvc in "${pvc_nums[@]}"
do
  echo "Pvc num: $pvc " >> $results_file
  for i in $(seq 1 $iterations_num);
  do
    export PVC_REPLICAS=$pvc
    run_workload
    delete_obj_with_time $NAMESPACE pvc $results_file
  done
done

cat $results_file