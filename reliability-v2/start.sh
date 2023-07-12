#/!/bin/bash
################################################
## Author: qili@redhat.com
## Description: Script to prepare and run reliability-v2 test
## To enable slack notification, export SLACK_API_TOKEN(ask qili for the token) 
## and SLACK_MEMBER(your slack member id)
################################################

function _usage {
    cat <<END
Usage: $(basename "${0}") [-p <path_to_auth_files>] [-n <folder_name> ] [-t <time_to_run>] -u

  -p <path_to_auth_files>      : The absolute path of the folder that contains the kubeconfig, admin file and users file.

  -n <folder_name>             : Name of the folder to save the test contents. Default is testYYYYMMDDHHMMSS
  
  -t <time_to_run>             : Time to run the reliability test. e.g. 1d10h3m10s,7d,5m. Default is 10m. 

  -u                           : Upgrade the cluster every 24 hours.

  -h                           : Help

END
}

if [[ "$1" = "" ]];then
    _usage
    exit 1
fi

while getopts ":n:t:p:uh" opt; do
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

# $1 path_to_kubeconfig, $2 path_to_admin_file, $3 path_to_users_file
function generate_config {
    echo "Generating reliabilty configuration file."
    get_os
    if [[ -s $2 ]]; then
        admin_name=$(cat $2 | cut -d ":" -f 1)
    else
        echo "[ERROR] '$2' is not a valid admin file path. Please provide the absolute path to the folder contains admin file with -p."
        exit 1
    fi

    if [[ $os == "linux" ]]; then
        sed -i s*'<path_to_kubeconfig>'*$1* reliability.yaml
        sed -i s*'<path_to_admin_file>'*$2* reliability.yaml
        sed -i s*'<path_to_users_file>'*$3* reliability.yaml
        sed -i s*'<path_to_script>'*$4* reliability.yaml
        sed -i s*'<path_to_content>'*$5* reliability.yaml
        if [[ $SLACK_API_TOKEN != "" || SLACK_WEBHOOK_URL != "" ]]; then
            sed -i s*'slack_enable: False'*'slack_enable: True'* reliability.yaml
            if [[ $SLACK_MEMBER != "" ]]; then
                sed -i s*'<Your slack member id>'*$SLACK_MEMBER* reliability.yaml
            fi
        fi
        sed -i s*'<admin_username>'*$admin_name* reliability.yaml

    elif [[ $os == "mac" ]]; then
        sed -i "" s*'<path_to_kubeconfig>'*$1* reliability.yaml
        sed -i "" s*'<path_to_admin_file>'*$2* reliability.yaml
        sed -i "" s*'<path_to_users_file>'*$3* reliability.yaml
        sed -i "" s*'<path_to_script>'*$4* reliability.yaml
        sed -i "" s*'<path_to_content>'*$5* reliability.yaml
        if [[ $SLACK_API_TOKEN != "" || SLACK_WEBHOOK_URL != "" ]]; then
            sed -i "" s*'slack_enable: False'*'slack_enable: True'* reliability.yaml
            if [[ $SLACK_MEMBER != "" ]]; then
                sed -i "" s*'<Your slack member id>'*$SLACK_MEMBER* reliability.yaml
            fi
        fi
        sed -i "" s*'<admin_username>'*$admin_name* reliability.yaml
    fi
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
echo start.sh logs will be saved to $start_log.

rm -rf halt

# Prepare venv
[[ -z $folder_name ]] && folder_name="test"$(date "+%Y%m%d%H%M%S")
mkdir $folder_name
echo "Test folder $folder_name is created."
cd $folder_name
echo "Preparing venv."
python3 --version
python3 -m venv reliability_venv > /dev/null
source reliability_venv/bin/activate > /dev/null
cd -
pip3 install --upgrade pip > /dev/null 2>&1
pip3 install -r requirements.txt > /dev/null 2>&1

# Prepare config yaml file
cp config/example_reliability.yaml $folder_name/reliability.yaml

cd $folder_name

script_folder=$RELIABILITY_DIR/tasks/script
content_folder=$RELIABILITY_DIR/content
if [[ ! -z $path_to_auth_files ]]; then
    generate_config $path_to_auth_files/kubeconfig $path_to_auth_files/admin $path_to_auth_files/users $script_folder $content_folder
    KUBECONFIG=$path_to_auth_files/kubeconfig
else
    echo "Please provide a valid path as -p path_to_auth_files."
    exit 1
fi

echo "export KUBECONFIG=$KUBECONFIG"
export KUBECONFIG

# Deploy NFS storage class for cluster without storageclass
cd $RELIABILITY_DIR

if [[ $(oc get storageclass -o json | jq .items) == "[]" ]];then
    cd utils
    echo "Deploy nfs-provisioner"
    #wget --quiet https://gitlab.cee.redhat.com/-/ide/project/wduan/openshift_storage/tree/master/-/nfs/deploy_nfs_provisioner.sh -O 
    #chmod +x deploy_nfs_provisioner.sh
    ./deploy_nfs_provisioner.sh
    cd -
fi

# Configure storage for monitoring
# https://docs.openshift.com/container-platform/4.12/scalability_and_performance/scaling-cluster-monitoring-operator.html#configuring-cluster-monitoring_cluster-monitoring-operator
oc get cm -n openshift-monitoring cluster-monitoring-config -o yaml  | grep volumeClaimTemplate > /dev/null 2>&1
if [[ $? -eq 1  ]]; then
    export STORAGE_CLASS=$(oc get storageclass | grep default | awk '{print $1}')
    export PROMETHEUS_RETENTION_PERIOD=30d
    export PROMETHEUS_STORAGE_SIZE=500Gi
    export ALERTMANAGER_STORAGE_SIZE=20Gi
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
        echo "Error: Prometheus status is '$prom_status'. 'success' is expected"
        exit 1
    else
        echo "Prometheus is success now."
    fi
fi

# Install dittybopper
cd $RELIABILITY_DIR

oc get ns| grep dittybopper
if [[ $? -eq 1 ]];then
    echo "Install dittybopper"
    cd utils
    if [[ ! -f performance-dashboards ]]; then
        git clone git@github.com:cloud-bulldozer/performance-dashboards.git
    fi
    cd performance-dashboards/dittybopper
    ./deploy.sh
    if [[ $? -eq 0 ]];then
        log "info" "dittybopper installed successfully."
    else
        log "info" "dittybopper install failed."
    fi
fi

# Cleanup test projects
cd $RELIABILITY_DIR
log "info" "Clearing test ns with label purpose=reliability."
oc delete ns -l purpose=reliability
# Start reliability test
log "info" "Start Reliability test. Log is writting to $folder_name/reliability.log."
# run in background and dont append output to nohup.out
nohup python3 reliability.py -c $folder_name/reliability.yaml -l $folder_name/reliability.log > /dev/null 2>&1 &
[[ -z $time_to_run ]] && time_to_run=10m
dhms_to_seconds $time_to_run
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
log "info" "Reliability test is halted after running $time_to_run. Please check logs in $folder_name/reliability.log."
