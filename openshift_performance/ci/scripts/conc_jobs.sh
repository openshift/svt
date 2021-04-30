#!/bin/bash

if [ "$#" -ne 1 ]; then
  jobs_amount=300
else
  jobs_amount=$1
fi

function prepare_project() {
  oc project default
  oc delete projects -l test=concurent-jobs
  while [ $(oc get projects | grep -c Terminating) -gt 0 ]; do
    oc get projects | grep -c Terminating
    sleep 5
  done
  oc new-project svt-conc-jobs-$jobs_amount
  oc label namespace svt-conc-jobs-$jobs_amount test=concurent-jobs
}

function create_jobs()
{
  for i in $(seq 1 $jobs_amount);
  do
    cat ../content/conc_jobs.yaml | sed "s/%JOB_ID%/$i/g" | oc create -f -
  done
}

function wait_for_completion()
{
  running=`oc get pods | grep -c Completed`
  while [ $running -lt $jobs_amount ]; do
    sleep 1
    running=`oc get pods | grep -c Completed`
    echo "$running jobs are completed"
  done
}

prepare_project
start_time=`date +%s`
create_jobs
wait_for_completion
end_time=`date +%s`

total_time=`echo $end_time - $start_time | bc`

echo "Time taken for creating $jobs_amount concurrent jobs with configmaps : $total_time"