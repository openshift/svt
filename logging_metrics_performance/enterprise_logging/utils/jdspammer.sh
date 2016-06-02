#!/bin/sh

################################################################################
##
##  journald-spammer.sh
##
##             - Write -r lines per minute of -l length to the systemd journal.
##
##  Usage:     ./journald.sh -r 60 -l 512 -v
##
################################################################################

# help text
show_help() {
cat << EOF
Usage: scriptname.sh [-hv] [-r lines_per_minute [-l line_length_in_chars]
Write -r lines per minute of -l length to the systemd journal.

    -h          display this help and exit
    -v          verbose mode
    -r          rate (lines per minute)
    -l          length of each line (in characters)

Example:
Values of -r 60 -l 512 would yield 30KB of log data every minute.

EOF
}


# ensure we have at least 1 argument
NUMARGS=$#
echo -e \\n"Number of arguments: $NUMARGS"
if [ $NUMARGS -eq 0 ]; then
  show_help
  exit 1;
fi


# init variables and setup getopts
verbose=0
OPTIND=1
while getopts "hvr:l:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        v)  verbose=$((verbose+1))
            ;;
        r)  rate=$OPTARG
            ;;
	    l)  length=${OPTARG}
	        ;;
        '?')
            show_help >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))" # Shift off the options and optional --.

minute=60
delay=$(( $minute/$rate ))
id=`hostname -s`
charset="[:alnum:]"

# generate random log string for this container
string=`cat /dev/urandom | tr -cd "$charset" | head -c $length`

if [ "$verbose" > 0 ]; then
echo "Config: $rate lines per minute, $length characters per line, string is $string"
fi

# main loop
while true ; do 
	if [ "$container" == "docker" ]; then
		echo $string
	else
		echo $string | systemd-cat
	fi
sleep $delay
done
