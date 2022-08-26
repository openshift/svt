#/!/bin/bash
################################################
## Auth=skordas@redhat.com prubenda@redhat.com qili@redhat.com
## Desription: Script to verify time of job creation with configMaps
## Polarion test case: OCP-22822 - Concurrent job creation with ConfigMaps
## https://polarion.engineering.redhat.com/polarion/redirect/project/OSE/workitem?id=OCP-22822
## Bug related: https://bugzilla.redhat.com/show_bug.cgi?id=1686503 
## https://github.com/kubernetes/kubernetes/issues/74412#issue-413387234 
## Cluster config: default
## job config: perfscale_regerssion_ci/content/conc_jobs.yaml
################################################ 

source ../common.sh

export jobs_amount=(${PARAMETERS:-300 400 600 800 900})
results_file=conc_jobs_result_$(date +%Y%m%d%H%M%S).out

name="concjobs"
label="test=$name"

function create_jobs() {
  for i in $(seq 1 $1); do
    cat ../../content/conc_jobs.yaml | sed "s/%JOB_ID%/$i/g" | oc create -f -
  done
}

function prepare_project() {
  oc new-project $name-$1
  oc label namespace $name-$1 $label
}

object_creation_types=(jobs configmaps pods)

for jobs in "${jobs_amount[@]}"; do
  delete_project_by_label $label
  prepare_project $jobs
  start_time=`date +%s`
  create_jobs $jobs
  wait_for_completion $name $jobs
  end_time=`date +%s`
  total_time=`echo $end_time - $start_time | bc`
  echo "Time taken for creating $jobs concurrent jobs with configmaps : $total_time seconds" >> $results_file
  #delete jobs and config maps
  delete_project_by_label $label
  for object_type in "${object_creation_types[@]}"
  do
    wait_for_termination $name $object_type
  done
  sleep 15
done

cat $results_file
