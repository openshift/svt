#!/usr/bin/env bash

function usage() {
cat << EOF
#
# Simple utility that uses ssh to check, run or kill the logger script
# on every node of the cluster.
# Automatically obtains the cluster nodes and writes them to a hosts file.
# NOTE: Runs in sequence not in parallel, although ssh -f is "non-blocking". 
#
# 
# EXAMPLES:
# 
# Run 3 busybox containers per each node logging at 128B/s. 
# export TIMES=3; export MODE=1; ./manage_pods.sh -r 128
#
#
# Run 5 standalone logger.sh processes logging forever
# export TIMES=5; export MODE=2; ./manage_pods.sh -r 128
#
# Both the above methods should log output to be picked up by the Fluentd pods.
#
#
# 
# Check for running pods.
# export MODE=1; ./manage_pods.sh -c 1
#
#
# Run 5 pods in every node. 
# The argument to '-r' is the log line length.
# This is the only argument that takes a value different than 1
#
# export TIMES=5; export MODE=1; ./manage_pods.sh -r 250 
#
# Kill pods in every node.
# export MODE=1; ./manage_pods.sh -k 1
#
# Check pods.
# export MODE=1; ./manage_pods.sh -c 1
#
EOF
exit 0
}

if [[ `id -u` -ne 0 ]]
then
    echo -e "Please run as root/sudo.\n"
    echo -e "Terminated."
    exit 1
fi

[[ $1 =~ "-h" ]] && usage

SCRIPTNAME=$(basename ${0%.*})
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKDIR=$SCRIPTDIR
UTILS=$WORKDIR/../utils
HOSTSFILE=$WORKDIR/hostlist.txt
DEFAULT_CONTAINER="gcr.io/google_containers/busybox:1.24"
DEFAULT_LOGGING_DRIVER=journald

declare -a NODELIST
source $UTILS/functions.sh
trap sig_handler SIGINT
set -o pipefail


# 'StrictHostKeyChecking no' should be set in the appropriate sshd cfg files.
# -o here is just for testing purposes.
function cp_logger() {
	for host in ${NODELIST[@]}
	do
		scp -o StrictHostKeyChecking=no $WORKDIR/logger.sh $host:
	done
}


function run_logger() {
	logdriver=${2:-$DEFAULT_LOGGING_DRIVER}

	for host in ${NODELIST[@]}
	do
		echo -e "\n\n[+] $host\nLine length: $x\nLogging driver: $logdriver"
		ssh -f -o StrictHostKeyChecking=no $host "/root/logger.sh -r 60 -l ${x} -t ${TIMES} -m ${MODE} -d $logdriver -i $DEFAULT_CONTAINER"
	done
}

function check_pods() {
	for host in ${NODELIST[@]}
	do
		ssh -o StrictHostKeyChecking=no $host "echo $host; docker ps | grep $DEFAULT_CONTAINER; echo"
	done
}

function kill_pods() {
	for host in ${NODELIST[@]}
	do
		echo -e "\n$host: $i"
  		ssh -f -o StrictHostKeyChecking=no $host "docker kill \$(docker ps | grep $DEFAULT_CONTAINER | awk '{print \$1}') 2>/dev/null"
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
  	read_hosts $HOSTSFILE
else
  	echo "First run:"
  	echo "Creating $HOSTSFILE ..."
  	oc get nodes | awk '{print $1}' | grep -v 'NAME' > $HOSTSFILE
  	[[ $? -eq 0 ]] && echo -e "Done.\n" || (echo 'Fatal: "oc get nodes failed."' ; exit $ERR)
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
while getopts ":s:r:c:k:q:d:" option; do
        case "${option}" in
          s) x=${OPTARG} && [[ $x -eq 1 ]] && cp_logger ;;
          r) x=${OPTARG} ;;
          d) d=${OPTARG} ;;
          c) c=${OPTARG} && [[ $c -eq 1 ]] && check_pods ;;
          k) k=${OPTARG} && [[ $k -eq 1 ]] && kill_pods ;;
          q) x=${OPTARG} && [[ $x -eq 1 ]] && kill_logger ;;
          '*')
            echo -e "Invalid option / usage: ${option}\nExiting."
            exit 1
          ;;
        esac
done
shift $((OPTIND-1))
fi

# x => log line_length 
# d => docker logging driver (journald, json-file, fluentd)
[[ $x -ne 0 ]] && run_logger $x $d

echo -e "\nDone."
exit $OK
