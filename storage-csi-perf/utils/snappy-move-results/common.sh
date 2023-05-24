#!/bin/bash
#set -xeEo pipefail
set -x

# Get OpenShift cluster details
export cluster_name=$(oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}')
export masters=$(oc get nodes -l node-role.kubernetes.io/master --no-headers=true | wc -l)
export workers=$(oc get nodes -l node-role.kubernetes.io/worker --no-headers=true | wc -l)
export infra=$(oc get nodes -l node-role.kubernetes.io/infra --no-headers=true | wc -l)
export platform=$(oc get infrastructure cluster -o jsonpath='{.status.platformStatus.type}')
export cluster_version=$(oc get clusterversion | grep -o [0-9.]* | head -1)
export network_type=$(oc get network cluster  -o jsonpath='{.status.networkType}' | tr '[:upper:]' '[:lower:]')
export folder_date_time=$(TZ=UTC date +"%Y-%m-%d_%I:%M_%p")
export SNAPPY_USER_FOLDER=${SNAPPY_USER_FOLDER:=perf-ci}

if [[ -n $SNAPPY_RUN_ID ]];then 
    export runid=$SNAPPY_RUN_ID-			#AIRFLOW run id
fi

#Function to store the run id, snappy path and other cluster details on elasticsearch
store_on_elastic()
{
    if [[ -n $SNAPPY_RUN_ID ]];then 
        export ES_SERVER_SNAPPY="https://search-perfscale-dev-chmf5l4sh66lvxbnadi4bznl3a.us-west-2.es.amazonaws.com:443"
        export ES_INDEX_SNAPPY=snappy
        export ts=`date +"%Y-%m-%dT%T.%3N"`

        curl -X POST -H "Content-Type: application/json" -H "Cache-Control: no-cache" -d '{
            "run_id" : "'$SNAPPY_RUN_ID'",
            "snappy_directory_url" : "'$SNAPPY_DATA_SERVER_URL/index/$SNAPPY_USER_FOLDER/$runid$platform-$cluster_version-$network_type/'",
            "snappy_folder_path" : "'$snappy_path'",
            "platform": "'$platform'",
            "cluster_name": "'$cluster_name'",
            "network_type": "'$network_type'",
            "cluster_version": "'$cluster_version'",
            "master_count": "'$masters'",
            "worker_count": "'$workers'",
            "infra_count": "'$infra'",            
            "Timestamp": "'$ts'"
            }' $ES_SERVER_SNAPPY/$ES_INDEX_SNAPPY/_doc/    
    fi
}
#generate metadata of cluster
generate_metadata()
{
    MASTER_COUNT=`oc get nodes -l node-role.kubernetes.io/master | grep -v NAME | wc -l`
    WORKER_COUNT=`oc get nodes -l node-role.kubernetes.io/worker | grep -v NAME | wc -l`
    INFRA_COUNT=`oc get nodes -l node-role.kubernetes.io/infra | grep -v NAME | wc -l`

    master=`oc get nodes -l node-role.kubernetes.io/master | grep -v NAME -m 1 | awk '{print $1}'`
    worker=`oc get nodes -l node-role.kubernetes.io/worker | grep -v NAME -m 1 | awk '{print $1}'`
    infra=`oc get nodes -l node-role.kubernetes.io/infra | grep -v NAME -m 1 | awk '{print $1}'`

    MASTER_NODE_TYPE=`oc describe node $master | grep "node.kubernetes.io/instance-type" | grep -oE "[^=]+$"`
    WORKER_NODE_TYPE=`oc describe node $worker | grep "node.kubernetes.io/instance-type" | grep -oE "[^=]+$"`
    INFRA_NODE_TYPE=`oc describe node $infra | grep "node.kubernetes.io/instance-type" | grep -oE "[^=]+$"`


    JSON_STRING=$( jq -n \
                    --arg mc "$MASTER_COUNT" \
                    --arg wc "$WORKER_COUNT" \
                    --arg ic "$INFRA_COUNT" \
                    --arg mt "$MASTER_NODE_TYPE" \
                    --arg wt "$WORKER_NODE_TYPE" \
                    --arg it "$INFRA_NODE_TYPE" \
                    '{MASTER_NODE_COUNT: $mc, WORKER_NODE_COUNT: $wc, INFRA_NODE_COUNT: $ic, MASTER_NODE_TYPE: $mt, WORKER_NODE_TYPE: $wt, INFRA_NODE_TYPE: $it}' )

    echo $JSON_STRING
}
