#!/usr/bin/env bash

#
# Simple utility that uses ssh to check, run or kill the logger script
# on every node of the cluster.
# Automatically obtains the cluster nodes and writes them to a hostsfile.
# NOTE: Runs in sequence not in paralell. 
#
# 
# EXAMPLES:
# 
# Runs 3 busybox containers per each node. 
# export TIMES=3;export MODE=1; ./manage_pods.sh -r 128
#
#
# Runs 5 standalone logger.sh processes logging forever
# export TIMES=5;export MODE=2; ./manage_pods.sh -r 128
#
# Both the above methods should log output to be picked up by the fluentd pods.
#
#
# Check for running pods.
# ./manage_pods.sh -c 1
#
# Run pods in every node. 
# The argument to '-r' is the log line length.
# This is the only arg that takes a value different than 1
#
# export TIMES=5;export MODE=2; ./manage_pods.sh -r 250 
#
#
# Kill pods in every node.
# export MODE=1; ./manage_pods.sh -k 1
#
# ./manage_pods.sh -c 1
#

set -o pipefail

if [[ `id -u` -ne 0 ]]
then
        echo -e "Please run as root/sudo.\n"
        echo -e "Terminated."
        exit 1
fi

SCRIPTNAME=$(basename ${0%.*})
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKDIR=$SCRIPTDIR
HOSTSFILE=$WORKDIR/hostlist.txt
declare -a NODELIST


function cp_logger() {
for host in ${NODELIST[@]}
do
  scp $WORKDIR/logger.sh $host:
done
}

function run_logger() {
for host in ${NODELIST[@]}
do
  echo -e "\n\n[+] Line length ${x}: $host"
  ssh -f $host "/root/logger.sh -r 60 -l ${x} -t ${TIMES} -m ${MODE}"
done
}

function check_pods() {
for host in ${NODELIST[@]}
do
  ssh $host "echo $host; docker ps | grep busybox; echo"
done
}

function kill_pods() {
for host in ${NODELIST[@]}
do
  echo -e "\n$host"
  ssh $host "docker kill \$(docker ps | grep busybox | awk '{print \$1}' ;echo)"
done
}

function check_logger() {
for host in ${NODELIST[@]}
do
  echo -e "\n$host"
  ssh $host "ps -ef | grep [l]ogger.sh"
done
}

function kill_logger() {
for host in ${NODELIST[@]}
do
  echo -e "\n$host"
  ssh $host "pkill -f logger.sh"
done
}

function read_hosts() {
  hf=${1}
  while read line; do NODELIST+=($line); done < $hf
}



# MAIN
if [[ -f $HOSTSFILE ]]
then
  echo -e "Hosts file exists.\n"
  read_hosts $HOSTSFILE
else
  echo "First run:"
  echo "Creating $HOSTSFILE ..."
  oc get nodes | awk '{print $1}' | grep -v 'NAME' > $HOSTSFILE
  [[ $? -eq 0 ]] && echo -e "Done.\n" || (echo 'Fatal: "oc get nodes failed."' ; exit 1)
  read_hosts $HOSTSFILE
  echo "Copying logger.sh to cluster nodes."
  cp_logger
  echo "Done."
fi


# for process mode
if [[ ${MODE} -eq 2 ]]; then
while getopts ":s:r:c:k:q:" option; do
        case "${option}" in
          s) x=${OPTARG} && [[ $x -eq 1 ]] && cp_logger ;;
          r)
             x=${OPTARG}
             if [[ $x -ne 0 ]]; then
                while [ ${TIMES} -ne 0 ]
                do
                  run_logger $x
                  ((TIMES--))
                done
             fi
          ;;
          c) x=${OPTARG} && [[ $x -eq 1 ]] && check_logger ;;
          k) x=${OPTARG} && [[ $x -eq 1 ]] && kill_logger ;;
          q) x=${OPTARG} && [[ $x -eq 1 ]] && kill_logger ;;
          '*')
            echo -e "Invalid option / usage: ${option}\nExiting."
            exit 1
          ;;
        esac
done
shift $((OPTIND-1))
fi

# container mode
if [[ ${MODE} -eq 1 ]]; then
while getopts ":s:r:c:k:q:" option; do
        case "${option}" in
          s) x=${OPTARG} && [[ $x -eq 1 ]] && cp_logger ;;
          r) x=${OPTARG} && [[ $x -ne 0 ]] && run_logger $x ;;
          c) x=${OPTARG} && [[ $x -eq 1 ]] && check_pods ;;
          k) x=${OPTARG} && [[ $x -eq 1 ]] && kill_pods ;;
          q) x=${OPTARG} && [[ $x -eq 1 ]] && kill_logger ;;
          '*')
            echo -e "Invalid option / usage: ${option}\nExiting."
            exit 1
          ;;
        esac
done
shift $((OPTIND-1))
fi

echo -e "\nDone."
exit 0
