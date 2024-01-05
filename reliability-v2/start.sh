#/!/bin/bash
################################################
## Author: qili@redhat.com
## Description: Script to prepare and run reliability-v2 test
## To enable slack notification, export SLACK_API_TOKEN(ask qili for the token) 
## and SLACK_MEMBER(your slack member id)
################################################

set -e

function _usage {
    cat <<END
Usage: $(basename "${0}") [-p <path_to_auth_files>] [-n <folder_name> ] [-t <time_to_run>] -u

  -p <path_to_auth_files>      : The absolute path of the folder that contains the kubeconfig, admin file and users file. Optional.

  -n <folder_name>             : Name of the folder to save the test contents. Default is testYYYYMMDDHHMMSS
  
  -t <time_to_run>             : Time to run the reliability test. e.g. 1d10h3m10s,7d,5m. Default is 10m.

  -r <tolerance_rate>          : Tolerance of failure rate. Default is 1(test fails when any failure rate is > 1%). 

  -u                           : Upgrade the cluster every 24 hours.

  -h                           : Help

END
}

if [[ "$1" = "" ]];then
    _usage
    exit 1
fi

while getopts ":n:t:p:r:uh" opt; do
    case ${opt} in
    n)
        folder_name=${OPTARG}
        ;;
    t)
        time_to_run=${OPTARG}
        ;;
    p)
        path_to_auth_files=${OPTARG}
        ;;
    r)
        tolerance_rate=${OPTARG}
        ;;
    u)
        upgrade=true
        ;;
    h)
        _usage
        exit 1
        ;;
    \?)
        echo -e "\033[32mERROR: Invalid option -${OPTARG}\033[0m" >&2
        _usage
        exit 1
        ;;
    :)
        echo -e "\033[32mERROR: Option -${OPTARG} requires an argument.\033[0m" >&2
        _usage
        exit 1
        ;;
    esac
done

# $1 info/warning/error, $2 log message
function log {
    red="\033[31m"
    green="\033[32m"
    yellow="\033[33m"
    end="\033[0m"
    current_date=$(date "+%Y%m%d %H:%M:%S")
    log_level=$(echo $1 | tr '[a-z]' '[A-Z]')
    log_path=$RELIABILITY_DIR/$folder_name/$start_log
    case ${log_level} in
    "INFO")
        echo -e "${green}[$current_date][$log_level] $2${end}" | tee -a $log_path;;
    "WARNING")
        echo -e "${yellow}[$current_date][$log_level] $2${end}" | tee -a $log_path;;
    "ERROR")
        echo -e "${red}[$current_date][$log_level] $2${end}" | tee -a $log_path;;
    esac
}

function get_os {
    if [[ $(uname -a) =~ "Darwin" ]]; then 
        os=mac
    else
        os=linux
    fi
}

# $1 path_to_kubeconfig, $2 path_to_admin_file, $3 path_to_users_file, $4 path_to_script, $5 path_to_content
# $6 path_to_reliability_config_file
function generate_config {
    echo "Generating reliabilty configuration file."
    get_os
    if [[ -s $2 ]]; then
        admin_name=$(cat $2 | cut -d ":" -f 1)
    else
        echo "[ERROR] '$2' is not a valid admin file path. Please provide the absolute path to the folder contains admin file with -p."
        exit 1
    fi
    reliability_config_file=$6
    set +e
    if [[ $os == "linux" ]]; then
        sed -i s*'<path_to_kubeconfig>'*$1* $reliability_config_file
        sed -i s*'<path_to_admin_file>'*$2* $reliability_config_file
        sed -i s*'<path_to_users_file>'*$3* $reliability_config_file
        sed -i s*'<path_to_script>'*$4* $reliability_config_file
        sed -i s*'<path_to_content>'*$5* $reliability_config_file
        if [[ $SLACK_API_TOKEN != "" || SLACK_WEBHOOK_URL != "" ]]; then
            sed -i s*'slack_enable: False'*'slack_enable: True'* $reliability_config_file
            if [[ $SLACK_MEMBER != "" ]]; then
                sed -i s*'<Your slack member id>'*$SLACK_MEMBER* $reliability_config_file
            fi
        fi
        sed -i s*'<admin_username>'*$admin_name* $reliability_config_file

    elif [[ $os == "mac" ]]; then
        sed -i "" s*'<path_to_kubeconfig>'*$1* $reliability_config_file
        sed -i "" s*'<path_to_admin_file>'*$2* $reliability_config_file
        sed -i "" s*'<path_to_users_file>'*$3* $reliability_config_file
        sed -i "" s*'<path_to_script>'*$4* $reliability_config_file
        sed -i "" s*'<path_to_content>'*$5* $reliability_config_file
        if [[ $SLACK_API_TOKEN != "" || SLACK_WEBHOOK_URL != "" ]]; then
            sed -i "" s*'slack_enable: False'*'slack_enable: True'* $reliability_config_file
            if [[ $SLACK_MEMBER != "" ]]; then
                sed -i "" s*'<Your slack member id>'*$SLACK_MEMBER* $reliability_config_file
            fi
        fi
        sed -i "" s*'<admin_username>'*$admin_name* $reliability_config_file
    fi
    set -e
    echo "Reliability config file is generated to $reliability_config_file."
}

# $1 number of seconds
function second_to_dhms {
    seconds=$1
    if [[ $seconds -lt 60 ]]; then
        human_readable_time="${second}s"
    elif [[ $seconds -ge 60 && $seconds -lt 3600 ]];then
        human_readable_time="$(( $seconds / 60 ))m$(( $seconds % 60 ))s"
    elif [[ $seconds -ge 3600 && $seconds -lt 86400 ]];then
        human_readable_time="$(( $seconds / 3600 ))h$(( ($seconds % 3600) / 60 ))m$(( ($seconds % 3600) % 60 ))s"
    elif [[ $seconds -ge 86400 ]];then
        human_readable_time="$(( $seconds / 86400 ))d$(( ($seconds % 86400) / 3600 ))h$(( (($seconds % 86400) % 3600)/ 60 ))m$(( (($seconds % 86400) % 3600) % 60 ))s"
    fi
    echo $human_readable_time
}

# $1 string of day hour minute second, e.g. 7d1h1m1s
function dhms_to_seconds {
    echo "Total time to run is: $1"
    dhms=$1
    days=$(echo $dhms | grep -Eo "^[1-9][0-9]*d" | cut -d 'd' -f 1)
    if [[ -n $days ]]; then
        SECONDS_TO_RUN=$(( $SECONDS_TO_RUN + $days * 86400 ))
    fi
    hours=$(echo $dhms | grep -Eo "[1-9][0-9]*h" | cut -d 'h' -f 1)
    if [[ -n $hours ]]; then
        SECONDS_TO_RUN=$(( $SECONDS_TO_RUN + $hours * 3600 ))
    fi
    minutes=$(echo $dhms | grep -Eo "[1-9][0-9]*m" | cut -d 'm' -f 1)
    if [[ -n $minutes ]]; then
        SECONDS_TO_RUN=$(( $SECONDS_TO_RUN + $minutes * 60 ))
    fi
    seconds=$(echo $dhms | grep -Eo "[1-9][0-9]*s" | cut -d 's' -f 1)
    if [[ -n $seconds ]]; then
        SECONDS_TO_RUN=$(( $SECONDS_TO_RUN + $seconds ))
    fi
    echo "Total seconds to run is: $SECONDS_TO_RUN"
}

RELIABILITY_DIR=$(cd $(dirname ${BASH_SOURCE[0]});pwd)
SECONDS_TO_RUN=0
start_log=start_$(date +"%Y%m%d_%H%M%S").log
echo "start.sh logs will be saved to $start_log."

rm -rf halt

# Prepare venv
[[ -z $folder_name ]] && folder_name="test"$(date "+%Y%m%d%H%M%S")
mkdir $folder_name
log "info" "Test folder $folder_name is created."
cd $folder_name
log "info" "====Preparing venv===="
python3 --version
python3 -m venv reliability_venv > /dev/null
source reliability_venv/bin/activate > /dev/null
cd -
pip3 install --upgrade pip > /dev/null 2>&1
pip3 install -r requirements.txt > /dev/null 2>&1

# Prepare config yaml file
cp config/example_reliability.yaml $folder_name/reliability.yaml
CONFIG_FILE=$RELIABILITY_DIR/$folder_name/reliability.yaml

# if path_to_auth_files is not provided, generate it with generate_auth_files.sh
if [[ -z $path_to_auth_files ]]; then
    path_to_auth_files=$RELIABILITY_DIR/utils/path_to_auth_files
    if [[ ! -f $path_to_auth_files/kubeconfig ]]; then
        cd $RELIABILITY_DIR/utils
        log "info" "====Generating auth files===="
        ./generate_auth_files.sh
    fi
fi

script_folder=$RELIABILITY_DIR/tasks/script
content_folder=$RELIABILITY_DIR/content
# generate reliability config file
if [[ ! -z $path_to_auth_files ]]; then
    log "info" "====Generating reliability config file===="
    generate_config $path_to_auth_files/kubeconfig $path_to_auth_files/admin $path_to_auth_files/users $script_folder $content_folder $CONFIG_FILE
    KUBECONFIG=$path_to_auth_files/kubeconfig
else
    log "error" "Please provide a valid path as -p path_to_auth_files."
    exit 1
fi

echo "export KUBECONFIG=$KUBECONFIG"
export KUBECONFIG

# Deploy NFS storage class for cluster without storageclass
cd $RELIABILITY_DIR

if [[ $(oc get storageclass -o json | jq .items) == "[]" ]];then
    cd utils
    log "info" "====Deploy nfs-provisioner===="
    #wget --quiet https://gitlab.cee.redhat.com/-/ide/project/wduan/openshift_storage/tree/master/-/nfs/deploy_nfs_provisioner.sh -O 
    #chmod +x deploy_nfs_provisioner.sh
    ./deploy_nfs_provisioner.sh
    cd -
    storageclass="nfs_provisioner"
fi

if [[ -z $time_to_run ]]; then
    time_to_run="10m"
fi
dhms_to_seconds $time_to_run

# Configure storage for monitoring
# https://docs.openshift.com/container-platform/4.12/scalability_and_performance/scaling-cluster-monitoring-operator.html#configuring-cluster-monitoring_cluster-monitoring-operator
set +e
oc get cm -n openshift-monitoring cluster-monitoring-config -o yaml  | grep volumeClaimTemplate > /dev/null 2>&1
if [[ $? -eq 1  ]]; then
    log "info" "====Configure storage for monitoring===="
    export STORAGE_CLASS=$(oc get storageclass | grep default | awk '{print $1}')
    # For test run longer than 10 days
    if [[ $SECONDS_TO_RUN -gt 864000 && $storageclass == "nfs_provisioner" ]]; then
        export PROMETHEUS_RETENTION_PERIOD=40d
        export PROMETHEUS_STORAGE_SIZE=500Gi
        export ALERTMANAGER_STORAGE_SIZE=20Gi
    # For test run equal or less than 10 days or using nfs_provisioner as storageclass uses node's local storage which has limited storage
    # https://issues.redhat.com/browse/OCPQE-13514
    elif [[ $SECONDS_TO_RUN -le 864000 ]]; then
        export PROMETHEUS_RETENTION_PERIOD=20d
        export PROMETHEUS_STORAGE_SIZE=50Gi
        export ALERTMANAGER_STORAGE_SIZE=5Gi
    fi
    envsubst < content/cluster-monitoring-config.yaml | oc apply -f -
    echo "Sleep 60s to wait for monitoring to take the new config map."
    sleep 60
    oc rollout status -n openshift-monitoring deploy/cluster-monitoring-operator
    oc rollout status -n openshift-monitoring sts/prometheus-k8s
    token=$(oc create token -n openshift-monitoring prometheus-k8s --duration=6h)
    URL=https://$(oc get route -n openshift-monitoring prometheus-k8s -o jsonpath="{.spec.host}")
    prom_status="not_started"
    echo "Sleep 30s to wait for prometheus status to become success."
    sleep 30
    retry=20
    while [[ "$prom_status" != "success" && $retry -gt 0 ]]; do
        retry=$(($retry-1))
        echo "Prometheus status is not success yet, retrying in 10s, retries left: $retry."
        sleep 10
        prom_status=$(curl -s -g -k -X GET -H "Authorization: Bearer $token" -H 'Accept: application/json' -H 'Content-Type: application/json' "$URL/api/v1/query?query=up" | jq -r '.status')
    done
    if [[ "$prom_status" != "success" ]]; then
        prom_status=$(curl -s -g -k -X GET -H "Authorization: Bearer $token" -H 'Accept: application/json' -H 'Content-Type: application/json' "$URL/api/v1/query?query=up" | jq -r '.status')
        log "error" "Prometheus status is '$prom_status'. 'success' is expected"
        exit 1
    else
        log "info" "Prometheus is success now."
    fi
fi

# Install dittybopper
cd $RELIABILITY_DIR

oc get ns| grep dittybopper
if [[ $? -eq 1 ]];then
    log "info" "====Install dittybopper===="
    cd utils
    if [[ ! -f performance-dashboards ]]; then
        git clone git@github.com:cloud-bulldozer/performance-dashboards.git
    fi
    cd performance-dashboards/dittybopper
    ./deploy.sh
    if [[ $? -eq 0 ]];then
        log "info" "dittybopper installed successfully."
    else
        log "error" "dittybopper install failed."
    fi
fi
set -e

# Cleanup test projects
cd $RELIABILITY_DIR
log "info" "====Clearing test ns with label purpose=reliability.===="
oc delete ns -l purpose=reliability
# Start reliability test
log "info" "====Start Reliability test. Log is writting to $folder_name/reliability.log.===="
# run in background and dont append output to nohup.out
nohup python3 reliability.py -c $folder_name/reliability.yaml -l $folder_name/reliability.log > /dev/null 2>&1 &
timestamp_start=$(date +%s)
timestamp_end=$(($timestamp_start + $SECONDS_TO_RUN))
if [[ $os == "linux" ]]; then
    date_end_format=$(date --date=@$timestamp_end)
elif [[ $os == "mac" ]]; then date_end_format=$(date -j -f "%s" $timestamp_end "+%Y-%m-%d %H:%M:%S")
fi
log "info" "Reliability test will run $time_to_run. Test will end on $date_end_format. \
If you want to halt the test before that, open another terminal and 'touch halt' under reliability-v2 folder."
log "warning" "DO NOT CTRL+c or terminate this session."

# time < 1day
if [ $SECONDS_TO_RUN -lt 86400 ]; then
    sleep $SECONDS_TO_RUN
    log "info" "Reliability will run $time_to_run , and end on $date_end_format. Log is writting to $folder_name/reliability.log."
else
# time > 1 day=86400s
    time_left=86400
    while [ $time_left -gt 0 ] ; do
        if [ $time_left -ge 86400 ]; then
            sleep 86400
        else
            sleep $time_left
        fi
        timestamp_now=$(date +%s)
        time_run_dhms=$(second_to_dhms $(($timestamp_now - $timestamp_start)))
        time_left=$(($timestamp_end - $timestamp_now))
        time_left_dhms=$(second_to_dhms $time_left)
        if [ $time_left -ge 0 ]; then
            log "info" "Reliability test has been run $time_run_dhms. Time left $time_left_dhms. It will end on $date_end_format. Log is writting to $folder_name/reliability.log."
        fi
        if [[ $upgrade && $time_left -gt 0 ]]; then
            upgrade_log=$RELIABILITY_DIR/$folder_name/upgrade_$(date +"%Y%m%d_%H%M%S").log
            log "info" "Will upgrade cluster to the latest Accept nightly build in background. Check the upgrade log in $upgrade_log."
            nohup ./upgrade.sh > $upgrade_log 2>&1 &
        fi
    done
fi

# Stop reliability test
touch halt
log "info" "Reliability test is stopped after running $time_to_run. Please check logs in $folder_name/reliability.log."

# Wait for all tasks to finish the last loop
sleep 600
process_name="reliability.py"
max_retries=8
retry_count=0
while [ $retry_count -lt $max_retries ]; do
    if ps aux | grep -v grep | grep "$process_name" > /dev/null; then
        echo "The process $process_name is still running. Waiting for it to terminate..."
        sleep 600
        retry_count=$(($retry_count+1))
    else
        echo "The process $process_name has been terminated."
        break
    fi
done
if [ $retry_count -eq $max_retries ]; then
    echo "Reliability test tasks are not stopped after 90 minutes"
    ps aux | grep -v grep | grep "reliability"
    exit 1
fi

# Check results
if [[ -z $tolerance_rate ]]; then
    tolerance_rate=1
fi
cd $folder_name
if [ ! -f reliability.log ]; then
    echo "reliability.log is not found."
    exit 1
fi
if grep 'Reliability test results' reliability.log -A 30 > reliability_result; then
    echo "========reliability_result========"
    cat reliability_result
    cat reliability_result| grep %|cut -d '%' -f 1|tr -d ' '|awk -v tr=$tolerance_rate -F'|' 'BEGIN{print "Tasks with failure rate > "tr"%:"}$5>=tr{print $1"Failure rate:" $5"%"}' > reliability_failures
    if [[ $(cat reliability_failures | wc -l) -gt 1 ]]; then
        echo "========reliability_failure========"
        cat reliability_failures
        exit 1
    else
        echo "Reliability Test Passed!"
    fi
else
    echo "Reliability test results missing, please check reliability.log"
    exit 1
fi
