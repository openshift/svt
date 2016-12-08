#!/usr/bin/env bash

SCRIPTNAME=$(basename ${0%.*})
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTILS=$SCRIPTDIR/utils

source $UTILS/functions.sh
trap sig_handler SIGINT


setup_globals

if [[ ! -f $PBENCH_NODESFILE ]]; then
  echo -e "$PBENCH_NODESFILE file, not found. Please create one.\nExit."
  exit $ERR
else
  mapfile -t NODELIST < $PBENCH_NODESFILE
fi

parse_opts $@
check_required $@
clean_pbench
pbench_perftest ${NODELIST[@]}

[[ $? -eq 0 ]] && exit $OK || exit $ERR
