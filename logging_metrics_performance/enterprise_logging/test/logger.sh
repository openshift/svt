#!/bin/sh

################################################################################
##
##  logger.sh
##
##             - Write -r lines per minute of -l length to any logging backend.
##
##  Usage:     ./logger.sh -r 60 -l 512 -t 5 -m 2
##
################################################################################

show_help() {
    cat << EOF
    Usage: scriptname.sh [-hv] [-r lines_per_minute [-l line_length_in_chars]
    Write -r lines per minute of -l length to the systemd journal.

    -h          display this help and exit
    -v          verbose mode
    -r          rate (lines per minute)
    -l          length of each line (in characters)
    -t          number of logger pods per node

    -d          log driver to use: --log-driver=journald | --log-driver=json-file
    		(https://docs.docker.com/engine/admin/logging/overview/)

    -m          run mode:
    		1 - container mode
    		2 - standalone process mode

    Example:
    Values of -r 60 -l 512 would yield 30KB of log data every minute.

EOF
}

NUMARGS=$#
if [ $NUMARGS -eq 0 ]; then
    show_help
    exit 1;
fi

modeflag=false

verbose=0
OPTIND=1
while getopts "hvr:m:l:t:d:i:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        v)  verbose=$((verbose+1))
            ;;
        r)  rate=$OPTARG
            ;;
        d)  log_driver=$OPTARG
            ;;
        i)  container_image=$OPTARG
            ;;
        l)  length=${OPTARG}
            ;;
        t)  xtimes=${OPTARG}
            ;;
        m)  modeflag=true; mode=${OPTARG}
            ;;
        '?')
            show_help >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))"

minute=60
udelay=$(( ($minute*1000000)/$rate ))
id=`hostname -s`
charset="[:alnum:]"
string=`cat /dev/urandom | tr -cd "$charset" | head -c $length`

if [ "$verbose" > 0 ]; then
    echo "Config: $rate lines per minute, $length characters per line, string is $string"
fi

# MAIN loop
i=0
if [[ $mode -eq 1 ]]; then
    echo -e "\nRunning in container mode."
    sleep 1
    while [ $i -lt ${xtimes} ]
    do
        echo "Container ${i}: $log_driver: $container_image"

        docker run -v /dev/log:/dev/log -it --privileged -d --log-driver=${log_driver} ${container_image} \
        "/bin/sh" "-c" "while true ; do logger -s -t EFK: ${string} ; usleep ${udelay}; done  " 
	
        ((i++))
    done
    echo
elif [[ $mode -eq 2 ]]; then
    echo -e "\nRunning in logger process mode."
    while true ; do logger ${string} ; usleep ${udelay}; done
    ((i++)); echo
else
    echo -e "\nInvalid mode. Should be \"1\" (container mode) or \"2\" (standalone process mode). Exiting."
    exit 1
fi

exit 0
