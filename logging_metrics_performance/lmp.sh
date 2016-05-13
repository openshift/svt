#!/bin/bash

# author: Chunyun Chen
# date: 11/05/2015
# email: chunchen@redhat.com
# IRC: chunchen @ aos-qe
# desc: Testing scalability for logging and metrics parts

# the format for *time* command: %E=real time, %U=user time, %S=system time
export TIMEFORMAT="%E %U %S"

OS_MASTER=""
MASTER_CONFIG="/etc/origin/master/master-config.yaml"
SUBDOMAIN=""
OS_USER="chunchen"
OS_PASSWD="redhat"
CURRENT_USER_TOKEN=""
MASTER_USER="root"
PROJECT="${OS_USER}pj"
RESULT_DIR=~/test/data
METRICS_PERFORMANCE_FILE="metrics_performance.txt"
LOGGING_PERFORMANCE_FILE="logging_performance.txt"
SSH="ssh $MASTER_USER@$OS_MASTER"

set -e

function get_nodes {
    oc get node |grep -v -e "SchedulingDisabled" -e "STATUS" |awk ' {print $1}'
}

function get_node_num {
    oc get node | grep -v -e "SchedulingDisabled" -e "STATUS" | wc -l
}

# add appropriate permissions for user
function add_permission {
    $SSH "oadm policy add-cluster-role-to-user cluster-admin $OS_USER"
}

Hawkular_metrics_appname="hawkular-metrics"
Kibana_ops_appname="kibana-ops"
Kibana_appname="kibana"

# Add public URL in /etc/origin/master/master-config.yaml for logging and metrics on master machine
function add_public_url {
    local restart_master="no"
    if [ -z "$($SSH "grep loggingPublicURL $MASTER_CONFIG")" ];
    then
        $SSH "sed -i -e '/publicURL:/a\  loggingPublicURL: https://$Kibana_ops_appname.$SUBDOMAIN' -e '/publicURL:/a\  loggingPublicURL: https://$Kibana_appname.$SUBDOMAIN' $MASTER_CONFIG"
        restart_master="yes"
    fi
    if [ -z "$($SSH "grep metricsPublicURL $MASTER_CONFIG")" ];
    then
        $SSH "sed -i '/publicURL:/a\  metricsPublicURL: https://$Hawkular_metrics_appname.$SUBDOMAIN/hawkular/metrics' $MASTER_CONFIG"
        restart_master="yes"
    fi
    if [ "$restart_master" == "yes" ];
    then
        $SSH "systemctl restart  atomic-openshift-master.service"
    fi
}

# fix admin permissions for service account
function fix_oadm_permission {
    local role="$1"
    local user="$2"
    oadm policy add-cluster-role-to-user $role $user
}

# fix SCC permissions for service account
function fix_scc_permission {
    local scc="$1"
    local user="$2"
    oadm policy add-scc-to-user $scc $user
}

# fix general permissions for service account
function fix_oc_permission {
    local role="$1"
    local user="$2"
    oc policy add-role-to-user $role $user
}

function get_resource_num {
    local regexp="$1"
    local resource="$2"
    oc get $resource| sed -n "/$regexp/p" |wc -l
}

function delete_oauthclient {
    # For logging part
    resource_num=$(get_resource_num "kibana-proxy" "oauthclients")
    if [ "$resource_num" == "1" ];
    then
        oc delete oauthclients "kibana-proxy"
    fi
}

function delete_project {
    local projects="$@"
    for project_name in $projects
    do
	    if [ "1" == "$(get_resource_num "$project_name" "projects")" ];
	    then
	      oc delete project $project_name
	      check_resource_validation "deleting project *$project_name*" "$project_name" "0" "projects"
	    fi
    done
}

function create_project {
    local project_name="${1:-$PROJECT}"
    if [ "0" == "$(get_resource_num "$project_name" "projects")" ];
    then
      oc new-project $project_name
      check_resource_validation "creating PROJECT *$project_name*" "$project_name" "1" "projects"
    fi
    oc project $project_name
}

# Log into OpenShift server and create PROJECT/namespace for user
function login_openshift {
    local del_proj="$1"
    oc login $OS_MASTER -u $OS_USER -p $OS_PASSWD
    add_permission
    add_public_url
    sleep 6  # wait master service started up
    CURRENT_USER_TOKEN=$(get_token_for_current_user)

    if [ "--del-proj" == "$del_proj" ];
    then
        delete_project $PROJECT $podproject
    fi
    create_project
}

# check specific pods number,eg: Running pod
function check_resource_validation {
    local msg_notification="$1"
    local regexp="$2"
    local resource_num="${3:-3}"
    local resource="${4:-pods}"
    echo "Wait $msg_notification..."
    while [ "$(get_resource_num "$regexp" "$resource")" != "$resource_num" ]
    do
        sleep 6
    done
    echo "Success for $msg_notification!"
}

# get the names of specific status pods, will get all pods in all PROJECTs on master by default
function get_resource_in_all_projects {
    local resource="$1"
    local regexp="$2"
    oc get $resource --all-namespaces | sed -n "/$regexp/p" | awk '{print $1,$2}'
}

function get_resource_in_a_project {
    local resource="$1"
    local project_name="$2"
    local regexp="$3"
    oc get $resource -n $project_name| sed -n "/$regexp/p" | awk '{print $1}'
}

function set_annotation {
    local is_name="$1"
    local annotation_name="${2:-openshift.io/image.insecureRepository}"
    local annotation_value="${3:-true}"
    oc patch imagestreams $is_name  -p ''{\"metadata\":{\"annotations\":{\"$annotation_name\":\"$annotation_value\"}}}''
}

SA_metrics_deployer="https://raw.githubusercontent.com/openshift/origin-metrics/master/metrics-deployer-setup.yaml"
HCH_stack="https://raw.githubusercontent.com/openshift/origin-metrics/master/metrics.yaml"
Image_prefix="${IMAGE_PREFIX:-rcm-img-docker01.example.com:5001/openshift3/}"
Image_version="${IMAGE_VERSION:-latest}"
Use_pv=false

# hch = hawkular, cassanda & heapster, they are Mertrics part
function up_hch_stack {
    # Create the Deployer Service Account
    oc create -f $SA_metrics_deployer
    # fix permissions for service account
    fix_oadm_permission cluster-reader system:serviceaccount:$PROJECT:heapster
    fix_oc_permission edit system:serviceaccount:$PROJECT:metrics-deployer
    # Create the Hawkular Deployer Secret
    oc secrets new metrics-deployer nothing=/dev/null
    # Deploy hch stack
    oc process -f $HCH_stack -v HAWKULAR_METRICS_HOSTNAME=$Hawkular_metrics_appname.$SUBDOMAIN,IMAGE_PREFIX=$Image_prefix,IMAGE_VERSION=$Image_version,USE_PERSISTENT_STORAGE=$Use_pv,MASTER_URL=https://$OS_MASTER:8443 \
    |oc create -f -
    check_resource_validation "starting Metrics stack" "\(heapster\|hawkular\).\+1\/1\s\+Running"
}

ES_ram="1024M"
ES_cluster_size="1"
EFK_deployer="https://raw.githubusercontent.com/openshift/origin-aggregated-logging/master/deployment/deployer.yaml"
torf=true

# efk = elasticsearch, fluentd & kibana, they are Logging part
function up_efk_stack {
    # Create the Deployer Secret
    oc secrets new logging-deployer nothing=/dev/null
    # Create the Deployer ServiceAccount
    oc create -f - <<API
apiVersion: v1
kind: ServiceAccount
metadata:
    name: logging-deployer
secrets:
- name: logging-deployer
API
    delete_oauthclient
    # fix permissions for service account
    fix_oc_permission edit system:serviceaccount:$PROJECT:logging-deployer
    fix_oadm_permission cluster-reader system:serviceaccount:$PROJECT:aggregated-logging-fluentd
    # Deploy efk stack
    oc process -f $EFK_deployer -v ENABLE_OPS_CLUSTER=$torf,IMAGE_PREFIX=$Image_prefix,KIBANA_HOSTNAME=$Kibana_appname.$SUBDOMAIN,KIBANA_OPS_HOSTNAME=$Kibana_ops_appname.$SUBDOMAIN,PUBLIC_MASTER_URL=https://$OS_MASTER:8443,ES_INSTANCE_RAM=$ES_ram,ES_CLUSTER_SIZE=$ES_cluster_size,IMAGE_VERSION=$Image_version,MASTER_URL=https://$OS_MASTER:8443 |oc create -f -
    check_resource_validation "completing EFK deployer" "\logging-deployer.\+0\/1\s\+Completed" "1"
    # Create the supporting definitions
    oc process logging-support-template | oc create -f -
    # Set annotation for each logging images
    for is in $(get_resource_in_a_project "imagestreams" "$PROJECT" "logging")
    do
        set_annotation $is
    done
    check_resource_validation "creating dc/logging-fluentd" "logging-fluentd" "1" "deploymentconfigs"
    check_resource_validation "creating rc/logging-fluentd-1" "logging-fluentd-1" "1" "replicationcontrollers"
    # Enable fluentd service account
    fix_scc_permission "privileged" "system:serviceaccount:$PROJECT:aggregated-logging-fluentd"
    # Scale Fluentd Pod
set -x
    local fluentd_pod_num=$(get_node_num)
    oc scale dc/logging-fluentd --replicas=$fluentd_pod_num
    oc scale rc/logging-fluentd-1 --replicas=$fluentd_pod_num
    check_resource_validation "starting EFK stack" "\(logging-es\|logging-fluentd\|logging-kibana\).\+\+Running" "$((4+$fluentd_pod_num))"
}

# Must have *cluster-admin* permission for log in user
function get_token_for_user {
    local user="$1"
    token=$(oc get oauthaccesstokens |grep $user |sort -k5 | tail -1 | awk '{print $1}')
    return $token
}

function get_token_for_current_user {
    oc whoami -t
}

function get_container_name_in_pod {
    local pod_name=$1
    local project_name=${2:-$PROJECT}
    oc describe pods $pod_name -n $project_name |sed -n '/Container ID/{g;1!p;};h' | sed 's/\( \|:\)//g'
}

function check_metrics_or_logs {
    local catalog=$1
    local project_name=${2:-$PROJECT}
    local pod_name=$3
    local pod_num=$(get_resource_num "\(Running\|Completed\)" "pods --all-namespaces")
    if [ "$catalog" == "efk" ];
    then
        for container_name in $(get_container_name_in_pod $pod_name $project_name):
        do
            (time curl -k -H "Authorization: Bearer $CURRENT_USER_TOKEN" https://$Kibana_appname.$SUBDOMAIN/#/discover?_a=\(columns:\!\(kubernetes_container_name,$container_name\),index:"$project_name.*",interval:auto,query:\(query_string:\(analyze_wildcard:\!t,query:"kubernetes_pod_name:%20${pod_name}%20%26%26%20kubernetes_namespace_name:%20$project_name"\)\),sort:\!\(time,desc\)\)\&_g=\(time:\(from:now-1w,mode:relative,to:now\)\)) 2> .ctime
        local curl_real_time=$(tail -1 .ctime | awk '{print $1}')
        echo "$curl_real_time" >> .allmetrics
        done
    else
        time (curl --insecure -H "Authorization: Bearer $CURRENT_USER_TOKEN" -H "Hawkular-tenant: $project_name" -X GET https://$Hawkular_metrics_appname.$SUBDOMAIN/hawkular/metrics/metrics?tags={"pod_name":"$pod_name"} 2>&- > .metric$RANDOM) 2> .ctime
        local curl_real_time=$(tail -1 .ctime | awk '{print $1}')
        echo "$pod_name $pod_num $curl_real_time" >> .allmetrics
    fi
}

function inspect_pods {
    local catalog=${1:-hch}
    local project_name=${2:-allprojects}
    local pod_name=$3
    echo "Wait to access Metrics/Logging for Pods..."
    cat /dev/null > .allmetrics
    if [ "$project_name" == "allprojects" ];
    then
        get_resource_in_all_projects "pods" "\(Running\|Completed\)" > allpods.txt
        while read LINE
        do
            local prj=$(echo "$LINE" | awk '{print $1}')
            local pod=$(echo "$LINE" | awk '{print $2}')
            check_metrics_or_logs $catalog $prj $pod
        done < allpods.txt
        rm -f ./allpods.txt
    elif [ -z "$pod_name" ];
    then
        pods=$(get_resource_in_a_project "pods" "$project_name" "\(Running\|Completed\)")
        for pod in $pods
        do
            check_metrics_or_logs $catalog $project_name $pod
        done
    else
        check_metrics_or_logs $catalog $project_name $pod_name
    fi
    if [ "hch" == "$catalog" ];
    then
        local pod_num=$(head -1 .allmetrics | awk '{print $1}')
        local min_time=$(awk 'BEGIN {min = 1999999} {if ($2<min) min=$2 fi} END {print  min*1000}' .allmetrics)
        local max_time=$(awk 'BEGIN {max = 0} {if ($2>max) max=$2 fi} END {print max*1000}' .allmetrics)
        local avg_time=$(awk '{sum+=$2} END {print (sum/NR)*1000}' .allmetrics)
        echo "$pod_num,$min_time,$avg_time,$max_time" >> $RESULT_DIR/$METRICS_PERFORMANCE_FILE && rm -f .ctime .metric .allmetrics
    else
        local container_num=$(cat .allmetrics | wc -l)
        local min_time=$(awk 'BEGIN {min = 1999999} {if ($1<min) min=$1 fi} END {print  min*1000}' .allmetrics)
        local max_time=$(awk 'BEGIN {max = 0} {if ($1>max) max=$1 fi} END {print max*1000}' .allmetrics)
        local avg_time=$(awk '{sum+=$1} END {print (sum/NR)*1000}' .allmetrics)
        echo "$container_num,$min_time,$avg_time,$max_time" >> $RESULT_DIR/$LOGGING_PERFORMANCE_FILE && rm -f .ctime .metric .allmetrics
    fi
    echo "Finished to access Metrics/Logging!"
}

podproject=${OS_USER}pj2
rcFile="https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/svt-mysql-rc.yaml"
rcName="mysql-1"
initialPodNum=1
scaleNum=20
loopScaleNum=30
function lm_performance {
  create_project $podproject
  oc create -f $rcFile
  check_resource_validation "creating POD *$rcName*" "$rcName.\+\s\+Running" "$initialPodNum"
  local inum=1
  while [ $inum -le $loopScaleNum ]
  do
    inspect_pods "efk"
    inspect_pods "hch"
    local pod_num=$(expr $initialPodNum + $inum \* $scaleNum)
    scale -p $podproject -o $rcName -n $pod_num
    check_resource_validation "creating PODs($pod_num) *$rcName*" "$rcName.\+\s\+Running" "$pod_num"
    inum=$(expr $inum + 1)
  done
}

function start_hch_and_efk {
    # If '$1' is --del-proj, then will delete the PROJECT named "$PROJECT" and re-create
    hch_pods_num=$(get_resource_num "\(heapster\|hawkular\).\+1\/1\s\+Running" "pods")
    efk_pods_num=$(get_resource_num "\(logging-es\|logging-fluentd\|logging-kibana\).\+\+Running" "pods")

    if [ 0 -eq $hch_pods_num ];
    then
        up_hch_stack
    fi

    if [ 0 -eq $efk_pods_num ];
    then
        up_efk_stack
    fi
}

function scale {
    local obj_name=""
    local resource_name="rc"
    local incremental_num=1
    local project_name="$PROJECT"
    local pod_num=""
    
    OPTIND=1
    while getopts ":r:i:n:p:o:" opt
    do
        case $opt in
            r) resource_name="$OPTARG" ;;
            i) incremental_num=$OPTARG ;;
            n) pod_num=$OPTARG ;;
            p) project_name="$OPTARG" ;;
            o) obj_name="$OPTARG" ;;
        esac
    done
    if [ -z "$pod_num" ];
    then
        current_pod_num=$(oc get pods -n $project_name |grep $obj_name |wc -l)
        pod_num=$(($current_pod_num+$incremental_num))
    fi
    echo "Scale $resource_name $obj_name to $pod_num"
    oc scale $resource_name $obj_name --replicas=$pod_num -n $project_name
}

function usage {
    echo "=============================================================================================================="
    echo "=============================================================================================================="
    echo "Usage:"
    echo "      $(basename $0) [-d] hch_up|efk_up"
    echo "              -d: Delete current project, then re-create it"
    echo "      $(basename $0) pfm_testing"
    echo "=============================================================================================================="
    echo "=============================================================================================================="
    echo "hch_up: Start Metrics stack application for Heapster,Cassada & Hawkular components"
    echo "efk_up: Start Logging stack application for Elasticsearch,Fluentd & Kibana components"
    echo "pfm: Execute logging and metrics performance testing"
}

function main {
    # If '-d' is specified, then will delete the PROJECT named "$PROJECT" and re-create
    local fun_obj="${!#}"
    local del_project=''
	while getopts ":d:r:i:n:p:o:" opt; do
        case $opt in
            d) del_project='--del-proj' ;;
        esac
    done

    login_openshift "$del_project"
    case $fun_obj in
        "hch_up")
            up_hch_stack
            ;;
        "efk_up")
            up_efk_stack
            ;;
        "pfm_testing")
            lm_performance
            ;;
        *) usage;;
    esac
}

main $*
