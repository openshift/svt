#!/bin/bash
source ../common.sh 
#set -eo pipefail

prometheus_namespace=openshift-monitoring

function help() {
    printf "\n"
    printf "Usage: source env.sh; $0\n"
    printf "\n"
    printf "options supported:\n"
    printf "\t OUTPUT_DIR=str,                       str=dir to store the capture prometheus data\n"
    printf "\t PROMETHEUS_CAPTURE=str,               str=true or false, enables/disables prometheus capture\n"
    printf "\t PROMETHEUS_CAPTURE_TYPE=str,          str=wal or full, wal captures the write ahead log and full captures the entire prometheus DB\n"
    printf "\t OPENSHIFT_MUST_GATHER=str,            str=true or false, gathers cluster data including information about all the operator managed components\n"
    printf "\t STORAGE_MODE=str,                     str=pbench, moves the results to the pbench results dir to be shipped to the pbench server in case the tool is run using pbench\n"
    printf "\t DATA_SERVER_URL=str                   str=url that points to an http server that hosts data"
}

echo "==========================================================================="
echo "                      RUNNING SCALE-CI-DIAGNOSIS                           "
echo "==========================================================================="

if [[ -z "$OUTPUT_DIR" ]]; then
    echo "Looks like OUTPUT_DIR is not defined, please check"
    help
    exit 1
fi

if [[ -z "$PROMETHEUS_CAPTURE" ]]; then
    echo "Looks like PROMETHEUS_CAPTURE is not defined, please check"
    help
    exit 1
fi

if [[ -z "$PROMETHEUS_CAPTURE_TYPE" ]]; then
    echo "Looks like PROMETHEUS_CAPTURE_TYPE is not defined, please check"
    help
    exit 1
fi

if [[ -z "$OPENSHIFT_MUST_GATHER" ]]; then
    echo "Looks like OPENSHIFT_MUST_GATHER is not defined, please check"
    help
    exit 1
fi

# Check for kubeconfig
openshift_login

# Check if oc client is installed
which oc &>/dev/null
echo "Checking if oc client is installed"
if [[ $? -ne 0 ]]; then
    echo "oc client is not installed, please install"
    exit 1
else
    echo "oc client is present"
fi

# pick a prometheus pod
prometheus_pod=$(oc get pods -n $prometheus_namespace | grep -w "Running" | awk -F " " '/prometheus-k8s/{print $1}' | tail -n1)

# get the timestamp
ts=$(TZ=UTC date +"%Y-%m-%d_%I-%M_%p")

function capture_wal() {
    echo "================================================================================="
    echo "               copying prometheus wal from $prometheus_pod                       "
    echo "================================================================================="
    oc cp $prometheus_namespace/$prometheus_pod:/prometheus/wal -c prometheus $OUTPUT_DIR/wal/
    XZ_OPT=--threads=0 tar cJf $OUTPUT_DIR/prometheus-$ts.tar.xz $OUTPUT_DIR/wal
    if [[ $? -eq 0 ]]; then
        rm -rf $OUTPUT_DIR/wal
    fi
}


function capture_full_db() {
    echo "================================================================================="
    echo "            copying the entire prometheus DB from $prometheus_pod                "
    echo "================================================================================="
    oc cp  $prometheus_namespace/$prometheus_pod:/prometheus/ -c prometheus $OUTPUT_DIR/data/
    XZ_OPT=--threads=0 tar cJf $OUTPUT_DIR/prometheus-$ts.tar.xz -C $OUTPUT_DIR/data .
    if [[ $? -eq 0 ]]; then
        rm -rf $OUTPUT_DIR/data
    fi
}


function must_gather() {
    oc adm must-gather -- bash -c 'gather && gather_network_logs && gather_network_ovn_trace'
    if [[ $? -eq 0 ]]; then
        XZ_OPT=--threads=0 tar cJf $OUTPUT_DIR/must-gather-$ts.tar.xz -C must-gather* .
    else
        echo "===================================Must-gather collection failed================================="
        exit 0
    fi

}


function prometheus_capture() {
    if [[ "$PROMETHEUS_CAPTURE_TYPE" == "wal" ]]; then
        capture_wal
    elif [[ "$PROMETHEUS_CAPTURE_TYPE" == "full" ]]; then
        capture_full_db
    else
        echo "Looks like $type is not a valid option, please check"
        help
    fi
}


function store() {
    # parameters
    #     1 function to capture data
    #     2 filename

    if [[ -z $STORAGE_MODE ]]; then
        echo "Looks like STORAGE_MODE is not defined, storing the results on local file system"
        $1;
    elif [[ $STORAGE_MODE == "snappy" ]]; then
        $1;
        echo -e "snappy server as backup enabled"
        source ../snappy-move-results/common.sh
        export snappy_path="$SNAPPY_USER_FOLDER/$runid$platform-$cluster_version-$network_type/$workload/$folder_date_time/"
         #generate_metadata > metadata.json  
         ../snappy-move-results/run_snappy.sh "$2" $snappy_path
         #../snappy-move-results/run_snappy.sh metadata.json $snappy_path
         store_on_elastic
         
    else
        echo "Invalid storage mode chosen. STORAGE_MODE is $STORAGE_MODE"
        exit 1
    fi
}


if [[ $PROMETHEUS_CAPTURE == "true" ]]; then
    export workload=prometheus 
    store prometheus_capture "prometheus-$ts.tar.xz"
fi


if [[ $OPENSHIFT_MUST_GATHER == "true" ]]; then
    export workload=${WORKLOAD:=must_gather}
    store must_gather "must-gather-$ts.tar.xz"
fi

