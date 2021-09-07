#/!/bin/bash

pvc_nums=(500 1000)
storage_classes=("ocs-storagecluster-cephfs" "ocs-storagecluster-ceph-rbd")
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

function rewrite_storage_class() {
  python -c "from scripts.pod_density import increase_pods; increase_pods.print_new_storage_class('$1','$loader_file')"
}

function delete_projects() {
  oc delete pvc --all -n pvcproject0
}

function wait_for_project_termination() {
  terminating=$(oc get pvc -n pvcproject0 | wc -l | xargs)
  while [ ${terminating} -ne 0 ]; do
    sleep 5
    terminating=$(oc get pvc -n pvcproject0 | wc -l | xargs)
    echo "$terminating pvc are still there"
  done
}

rm -irf $results_file

for pvc in "${pvc_nums[@]}"; do
  echo "Pvc num: $pvc " >> $results_file
  for storageclass in ${storage_classes[@]}; do
    rewrite_storage_class $storageclass
    echo "storage class $storageclass"
    rewrite_yaml $pvc
    create_projects
    start_time=`date +%s`
    delete_projects
    wait_for_project_termination

    stop_time=`date +%s`
    total_time=`echo $stop_time - $start_time | bc`
    echo -e "\t Iteration $storageclass Deletion Time - $total_time" >> $results_file

  done
done

cat $results_file
