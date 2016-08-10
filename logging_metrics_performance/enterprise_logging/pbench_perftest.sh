#!/usr/bin/env bash

SCRIPTNAME=$(basename ${0%.*})
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTILS=$SCRIPTDIR/utils
source $UTILS/functions.sh

trap sig_handler SIGINT

# oc get pods -o wide -l component=es
# need to use bash4 hashmap here: [podname] [nodeip]

# .234 registryrouter_fluentd
# .247 clustermaster1_fluentd
# .73 fluentd73

NODELIST=("172.31.32.234 172.31.10.247 172.31.28.73")

setup_globals
parse_opts $@
check_required $@
clean_pbench
pbench_perftest ${NODELIST[@]}

[[ $? -eq 0 ]] && exit $OK || exit $ERR
