#!/bin/bash
################################################
## Author: qili@redhat.com
## Description: Script for cronjob typ of workload
## Task: https://issues.redhat.com/browse/OCPQE-13863
## Bugs: https://issues.redhat.com/browse/OCPBUGS-7962
## https://issues.redhat.com/browse/OCPBUGS-8217
## https://issues.redhat.com/browse/OCPBUGS-8439
## https://issues.redhat.com/browse/OCPBUGS-3652
## During the test, check the inode and worker node's memory usage on dittybopper's openshift-performance dashboard.
## Reference: https://docs.openshift.com/container-platform/4.12/nodes/jobs/nodes-nodes-jobs.html#nodes-nodes-jobs-creating-cron_nodes-nodes-jobs
################################################

USER=${USER:-""}
GROUP=${GROUPNAME:-""}
image="image-registry.openshift-image-registry.svc:5000/openshift/cli"
cmd="/bin/sh -c date"
ns="${GROUP}-${USER}-0"
cronjob_prefix="cronjob"

function usage {
    echo "Usage: $(basename "${0}") [-n <number of cronjobs>] [-s <schedule>] -d"
    echo "-n <number>                  : Number of cronjobs to be created. Default is 1."
    echo "-s <schedule>                : Schedule for the cronjob. Default is '*/1 * * * *'"
    echo "-d                           : Delete all cronjobs"
    echo "-c                           : Check all jobs"
    echo "-h                           : Help"
}

# delete all cronjobs under the namespace
function delete_all_cronjobs {
    oc delete -n $ns cronjob --all
}

# check pods created by the cronjob in the namespace
function check_cronjob_pod {
    pod_status_retry=10
    pod_status_retry_interval=30
    while [[ pod_status_retry -ne 0 ]]
    do
        fail=0
        succeed=0
        temp_file="pod_$RANDOM"
        oc get pod -n $ns --no-headers | grep $cronjob_prefix > $temp_file
        if [[ ! -f $temp_file ]]; then
            echo "[FAIL] no job pod is found for the cronjob under namespace $ns."
            oc get all -n $ns
            exit 1
        fi
        while read line; do
            name=$(echo $line | awk '{print $1}')
            status=$(echo $line | awk '{print $3}')
            if [[ $status != "Completed" && $status != "Running" && $status != "ContainerCreating" ]]; then
                fail=$(($fail+1))
                oc logs -n $ns $name
            else
                succeed=$(($succeed+1))
            fi
        done < $temp_file
        rm $temp_file
        if [[ $fail -gt 0 ]];then
            sleep $pod_status_retry_interval
            pod_status_retry=$(($pod_status_retry-1))
        else
            break
        fi
    done
    if [[ $fail -gt 0 ]];then
        echo "[FAIL] $fail cronjob's pod $name under namespace $ns are unhealthy. Please check the pod's log."
        exit 1
    else
        echo "[PASS] All $succeed cronjob's pods under namespace $ns are healthy."
        exit 0
    fi
}

if [[ "$1" = "" ]];then
    usage
    exit 1
fi

while getopts ":n:s:cdh" opt; do
    case ${opt} in
    n)
        number=${OPTARG}
        ;;
    s)
        schedule=${OPTARG}
        ;;
    d)
        delete_all_cronjobs
        exit
        ;;
    c)
        check_cronjob_pod
        ;;
    h)
        usage
        exit 1
        ;;
    \?)
        echo -e "\033[32mERROR: Invalid option -${OPTARG}\033[0m" >&2
        usage
        exit 1
        ;;
    :)
        echo -e "\033[32mERROR: Option -${OPTARG} requires an argument.\033[0m" >&2
        usage
        exit 1
        ;;
    esac
done

#use test namespace
oc project $ns
# cleanup cronjobs under the test namespace
delete_all_cronjobs

[[ -z $number ]] && number=1
# schedule a new job every 1 minutes
[[ -z $schedule ]] && schedule="*/1 * * * *"

# create $number of cronjob
for i in `seq $number`; do
    oc create cronjob -n $ns $cronjob_prefix-$i "--schedule=$schedule" --image=$image -- $cmd
    if [[ $? == 1 ]]; then
        echo "[FAIL] creating cronjob-$i failed."
        exit 1
    fi
done

# wait the first jobs to be completed
job_pod_retry=60
job_pod_retry_interval=30
while [[ $(oc get pod -n $ns | grep "Completed") ]]
do
    job_pod_retry=$(($job_pod_retry-1))
    if [[ $job_pod_retr -eq 0 ]]; then
        break
    fi
    echo "Wait until cronjobs got completed once...Retry left: $job_pod_retry"
    sleep $job_pod_retry_interval
done
if [[ $job_pod_retry -eq 0 ]]; then
    echo "[FAIL] Jobs were not successfully COMPLETIONS after 60 retry, please debug."
    exit 1
fi

echo "[PASS] creating $number cronjobs succeeded."
exit 0
