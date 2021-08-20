#!/bin/bash

jobs_amount=(300 400 600 800 900)
results_file=conc_jobs_result_$(date +%Y%m%d%H%M%S).out

function create_jobs() {
  for i in $(seq 1 $1); do
    cat ../content/conc_jobs.yaml | sed "s/%JOB_ID%/$i/g" | oc create -f -
  done
}

function wait_for_completion() {
  COUNTER=0
  running=$(oc get pods | grep job- | grep -c Completed)
  while [ $running -lt $1 ]; do
    sleep 1
    running=$(oc get pods | grep job- | grep -c Completed)
    echo "$running jobs are completed"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 1200 ]; then
      echo "$running pods are still not complete after 20 minutes"
      exit 1
    fi
  done
}

function prepare_project() {
  oc new-project svt-conc-jobs-$1
  oc label namespace svt-conc-jobs-$1 test=concurent-jobs
}

function delete_project() {
  oc project default
  oc delete projects -l test=concurent-jobs --wait=false
  while [ $(oc get projects -l test=concurent-jobs | grep -c svt-conc-jobs) -gt 0 ]; do
    echo "Waiting for projects to delete"
    sleep 5
  done
}

function wait_for_termination() {
  string=$1
  object_types=($@)
  for object_type in "${object_types[@]}"
  do
    COUNTER=0
    existing_obj=$(oc get $object_type -A| grep job- | wc -l)
    while [ $existing_obj -ne 0 ]; do
      sleep 5
      existing_obj=$(oc get $object_type -A | grep job- | wc -l | xargs )
      echo "Waiting for $object_type to be deleted: $existing_obj still exist"
      COUNTER=$((COUNTER + 1))
      if [ $COUNTER -ge 60 ]; then
        echo "$creating $object_type are still not deleted after 5 minutes"
        exit 1
      fi
    done
    echo "All $object_type are deleted"
  done

}

object_creation_types=(jobs configmaps pods)

for jobs in "${jobs_amount[@]}"; do
  prepare_project $jobs
  start_time=`date +%s`
  create_jobs $jobs
  wait_for_completion $jobs
  end_time=`date +%s`
  total_time=`echo $end_time - $start_time | bc`
  echo "Time taken for creating $jobs concurrent jobs with configmaps : $total_time seconds" >> $results_file
  #delete jobs and config maps
  delete_project
  wait_for_termination "${object_creation_types[@]}"
  sleep 15
done

cat $results_file