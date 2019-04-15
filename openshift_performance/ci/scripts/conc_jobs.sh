#!/bin/bash

jobs_amount=300

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

start_time=`date +%s`
create_jobs
wait_for_completion
end_time=`date +%s`

total_time=`echo $end_time - $start_time | bc`

echo "Time taken for creating $jobs_amount concurrent jobs with configmaps : $total_time"