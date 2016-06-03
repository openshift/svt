#!/usr/bin/env bash

SCRIPTNAME=$(basename ${0%.*})
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTILS=$SCRIPTDIR/utils
source $UTILS/functions.sh

trap sig_handler SIGINT

# oc get pods -o wide -l component=es
# need to use bash4 hashmap here: [podname] [nodeip]
NODELIST=("192.1.11.83 192.1.11.226 192.1.11.66")

setup_globals
parse_opts $@
check_required $@
clean_pbench
pbench_perftest ${NODELIST[@]}

[[ $? -eq 0 ]] && exit $OK || exit $ERR
