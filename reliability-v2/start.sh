#/!/bin/bash
################################################
## Author: qili@redhat.com
## Description: Script to prepare and run reliability-v2 test
## To enable slack notification, export SLACK_API_TOKEN(ask qili for the token) 
## and SLACK_MEMBER(your slack member id)
################################################

function _usage {
    cat <<END
Usage: $(basename "${0}") [-p <path_to_auth_files>] [-t <time_to_run>] -u

       $(basename "${0}") [-k <kubeconfig_path>] [-s <users.spec_path>] [-a <kubeadmin-password_path>] [-t <time_to_run>]   
       
       $(basename "${0}") [-i <flexy_install_build_id>] [-t <time_to_run>]

  -n <folder_name>             : Name of the folder to save the test contents. Default is testYYYYMMDDHHMMSS
  
  -t <time_to_run>             : Time to run the reliability test. e.g. 1d10h3m10s,7d,5m. Default is 10m. 

  -p <path_to_auth_files>       : The local path that contains the kubeconfig, kubeadmin-password and users.spec files.
  
  -k <kubeconfig_path>         : The local path to kubeconfig file.

  -a <kubeadmin-password_path> : The local path to kubeadmin-password file.

  -s <users.spec_path>         : The local path to users.spec file.

  -i <flexy_install_build_id>  : The build id of Flexy-install job. Use this when the server can connect to Jenkins. 

  -u                           : Upgrade the cluster every 24 hours.

  -h                           : Help

END
}

if [[ "$1" = "" ]];then
    _usage
    exit 1
fi

while getopts ":n:t:p:k:a:s:i:uh" opt; do
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
    k)
        kubeconfig=${OPTARG}
        ;;
    a)
        kubeadmin_password=${OPTARG}
        ;;
    s)
        users_spec="${OPTARG}"
        ;;
    i)
        flexy_install_build_id=${OPTARG}
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

SECONDS_TO_RUN=0

start_log=start_$(date +"%Y%m%d_%H%M%S").log
echo start.sh logs will be saved to $start_log.

# $1 info/warning/error, $2 log message
function log {
    red="\033[31m"
    green="\033[32m"
    yellow="\033[33m"
    end="\033[0m"
    current_date=$(date "+%Y%m%d %H:%M:%S")
    log_level=$(echo $1 | tr '[a-z]' '[A-Z]')
    case ${log_level} in
    "INFO")
        echo -e "${green}[$current_date][$log_level] $2${end}" | tee -a $start_log;;
    "WARNING")
        echo -e "${yellow}[$current_date][$log_level] $2${end}" | tee -a $start_log;;
    "ERROR")
        echo -e "${red}[$current_date][$log_level] $2${end}" | tee -a $start_log;;
    esac
}

function get_os {
    if [[ $(uname -a) =~ "Darwin" ]]; then 
        os=mac
    else
        os=linux
    fi
}

# $1 path_to_kubeconfig, $2 path_to_kubeadmin-password, $3 path_to_users.spec
function generate_config {
    echo "Generating reliabilty configuration file."
    get_os
    if [[ $os == "linux" ]]; then
        sed -i s*'<path_to_kubeconfig>'*$1* reliability.yaml
        sed -i s*'<path_to_kubeadmin-password>'*$2* reliability.yaml
        sed -i s*'<path_to_users.spec>'*$3* reliability.yaml
        if [[ $SLACK_API_TOKEN != "" ]]; then
            sed -i s*'slack_enable: False'*'slack_enable: True'* reliability.yaml
            if [[ $SLACK_MEMBER != "" ]]; then
                sed -i s*'<Your slack member id>'*$SLACK_MEMBER* reliability.yaml
            fi
        fi
    elif [[ $os == "mac" ]]; then
        sed -i "" s*'<path_to_kubeconfig>'*$1* reliability.yaml
        sed -i "" s*'<path_to_kubeadmin-password>'*$2* reliability.yaml
        sed -i "" s*'<path_to_users.spec>'*$3* reliability.yaml
        if [[ $SLACK_API_TOKEN != "" ]]; then
            sed -i "" s*'slack_enable: False'*'slack_enable: True'* reliability.yaml
            if [[ $SLACK_MEMBER != "" ]]; then
                sed -i "" s*'<Your slack member id>'*$SLACK_MEMBER* reliability.yaml
            fi
        fi
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
    echo $dhms | egrep "^[1-9]{1,}d"
    if [[ $? -eq 0 ]]; then
        days=$(echo $dhms | cut -d 'd' -f 1)
        SECONDS_TO_RUN=$(( $SECONDS_TO_RUN + $days * 86400 ))
    fi
    echo $dhms | egrep "d[1-9]{1,}h"
    if [[ $? -eq 0 ]]; then
        hours=$(echo $dhms | cut -d 'd' -f 2 | cut -d 'h' -f 1)
        SECONDS_TO_RUN=$(( $SECONDS_TO_RUN + $hours * 3600 ))
    fi
    echo $dhms | egrep "h[1-9]{1,}m"
    if [[ $? -eq 0 ]]; then
        minutes=$(echo $dhms | cut -d 'h' -f 2 | cut -d 'm' -f 1)
        SECONDS_TO_RUN=$(( $SECONDS_TO_RUN + $minutes * 60 ))
    fi
    echo $dhms | egrep "m[1-9]{1,}s"
    if [[ $? -eq 0 ]]; then
        seconds=$(echo $dhms | cut -d 'm' -f 2 | cut -d 's' -f 1)
        SECONDS_TO_RUN=$(( $SECONDS_TO_RUN + $seconds ))
    fi
    echo "Total seconds to run is: $SECONDS_TO_RUN"
}

rm -rf halt

[[ -z $folder_name ]] && folder_name="test"$(date "+%Y%m%d%H%M%S")
mkdir $folder_name
echo "Test folder $folder_name is created."
cd $folder_name
echo "Preparing venv."
python3 --version
python3 -m venv reliability_venv > /dev/null
source reliability_venv/bin/activate > /dev/null
cd -
pip3 install -r requirements.txt > /dev/null 2>&1

cp config/example_reliability.yaml $folder_name/reliability.yaml

cd $folder_name


if [[ ! -z $path_to_auth_files ]]; then
    generate_config $path_to_auth_files/kubeconfig $path_to_auth_files/kubeadmin-password $path_to_auth_files/users.spec
    KUBECONFIG=$path_to_auth_files/kubeconfig
elif [[ ! -z $flexy_install_build_id ]]; then
    JENKINS_JOB_URL="https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/ocp-common/job/Flexy-install/$flexy_install_build_id"
    KUBECONFIG_URL="$JENKINS_JOB_URL/artifact/workdir/install-dir/auth/kubeconfig"
    KUBEADMINPASSWORD_URL="$JENKINS_JOB_URL/artifact/workdir/install-dir/auth/kubeadmin-password"
    USERSSPEC_URL="$JENKINS_JOB_URL/artifact/users.spec"
    wget --quiet "$KUBECONFIG_URL" -O kubeconfig
    wget --quiet "$KUBEADMINPASSWORD_URL" -O kubeadmin-password
    wget --quiet "$USERSSPEC_URL" -O users.spec
    current_pwd=$(pwd)
    generate_config $current_pwd/kubeconfig $current_pwd/kubeadmin-password $current_pwd/users.spec
    KUBECONFIG=$current_pwd/kubeconfig
elif [[ ! -z $kubeconfig && ! -z $users_spec && ! -z $kubeadmin_password ]]; then
    generate_config $kubeconfig $kubeadmin_password $users_spec
    KUBECONFIG=$kubeconfig
fi

echo "export KUBECONFIG=$KUBECONFIG"
export KUBECONFIG
oc get ns| grep dittybopper
if [[ $? -eq 1 ]];then
    echo "Install dittybopper"
    git clone git@github.com:cloud-bulldozer/performance-dashboards.git
    cd performance-dashboards/dittybopper
    ./deploy.sh
fi

cd -

if [[ $(oc get storageclass -o json | jq .items) == "[]" ]];then
    cd utils
    echo "Deploy nfs-provisioner"
    #wget --quiet https://gitlab.cee.redhat.com/-/ide/project/wduan/openshift_storage/tree/master/-/nfs/deploy_nfs_provisioner.sh -O 
    #chmod +x deploy_nfs_provisioner.sh
    ./deploy_nfs_provisioner.sh
    cd -
fi

log "info" "Start Reliability test. Log is writting to $folder_name/reliability.log."
# run in background and dont append output to nohup.out
nohup python3 reliability.py -c $folder_name/reliability.yaml -l $folder_name/reliability.log > /dev/null 2>&1 &
[[ -z $time_to_run ]] && time_to_run=10m
dhms_to_seconds $time_to_run
timestamp_start=$(date +%s)
timestamp_end=$(($timestamp_start + $SECONDS_TO_RUN))
if [[ $os == "linux" ]]; then
    date_end_format=$(date --date=@$timestamp_end)
elif [[ $os == "mac" ]]; then
    date_end_format=$(date -j -f "%s" $timestamp_end "+%Y-%m-%d %H:%M:%S")
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
            upgrade_log=$folder_name/upgrade_$(date +"%Y%m%d_%H%M%S").log
            log "info" "Will upgrade cluster to the latest Accept nightly build in background. Check the upgrade log in $upgrade_log."
            nohup ./upgrade.sh > $upgrade_log 2>&1 &
        fi
    done
fi

touch halt
log "info" "Reliability test is halted after running $time_to_run. Please check logs in $folder_name/reliability.log."
