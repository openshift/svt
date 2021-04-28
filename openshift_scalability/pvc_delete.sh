#/!/bin/bash

pvc_nums=(10 20 30 50 100 200)
iterations_num=3
results_file=pvc_delete.out
loader_file=./content/pvc-templates/pvc-parameters.yaml
cloud_provider=aws

function create_projects() {
  echo "create projects variable $loader_file"
  python cluster-loader.py -f $loader_file -v
}

function rewrite_yaml() {
  python -c "from scripts.pod_density import increase_pods; increase_pods.print_new_yaml_temp($1,'$loader_file')"
}


function delete_projects()
{
  echo "deleting pvc"
  oc delete pvc --all -n pvcproject0
}

function wait_for_project_termination()
{
  terminating=`oc get pv | grep pvcproject0 | wc -l`
  while [ ${terminating} -ne 0 ]; do
  sleep 5
  terminating=`oc get pv | grep pvcproject0 | wc -l`
  echo "$terminating pv are still there"
  done
}

function create_sk2_storageclass() {

  storage_classes=$(oc get storageclass --no-headers -o name)
  sk2_exists=true
  for storage_class in $storage_classes; do
    if [[ $storage_class =~ "sk2" ]]; then
      sk2_exists=false
      echo "exists"
    fi
  done
  if $sk2_exists; then
    echo "create"
    if [[ $cloud_provider == "azure" ]]; then
      oc create -f ./content/pvc-templates/sk2_azure.yaml
    elif [[ $cloud_provider == "gcp" ]]; then
      echo "create gcp sk2"
      oc create -f ./content/pvc-templates/sk2_gcp.yaml
    else
      oc create -f ./content/pvc-templates/sk2.yaml
    fi
  fi
}


rm -irf $results_file


create_sk2_storageclass
for pvc in "${pvc_nums[@]}"
do
  echo "Pvc num: $pvc " >> $results_file
  for i in $(seq 1 $iterations_num);
  do
    rewrite_yaml $pvc
    create_projects
    start_time=`date +%s`
    delete_projects
    wait_for_project_termination

    stop_time=`date +%s`
    total_time=`echo $stop_time - $start_time | bc`
    echo -e "\t Iteration $i Deletion Time - $total_time" >> $results_file

  done
done

cat $results_file