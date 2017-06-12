#!/usr/bin/env bash

# script to run sysbench test inside pod - assumes sysbench and mariadb installed
# sysbench test run are CPU and oltp.lua - for more information about sysbench refer to
# https://www.percona.com/docs/wiki/benchmark_sysbench_oltp.html


# defautls
NOK=1
# make dirs inside pod for mariadb
DB_DIR="/root/"
THREADS="1"
MARIADBCONF="/etc/my.cnf"
DATE=`date +%Y-%m-%d-%H-%M-%S`
sysbench_bin=$(which sysbench)

usage() {
        printf  "Usage: ./$(basename $0) -d directory -t threads\n"
        printf -- "-d|--directory: directory which will be used by mariadb for read/write operations - this has to be provided otherwise /root/data and /root/datalog will be used\n"
        printf -- "-t|--threads : comma seperated list of values for number of threads\n"
        printf -- "-o|--oltp: number of rows in test table\n"
        printf -- "-r|--resultdir - the location where sybench results will be saved\n"
        printf -- "--cpuprime - For cpu test we have to specify --cpuprime parameter, eg 10000\n"
        printf -- "--maxreq - For oltp test type this is the value for meximum number of requests\n"
        printf -- "--testtype - Run CPU test: --testtype=cpu,or OLDP test: --testtype=oltp,or both: --testype=oltpcpu\n"
        exit 0
}

if [ "$EUID" -ne 0 ] || [ "$#" -eq 0 ] ; then
    printf "Necessary to be root to run script and necessary to provide script parameters\n"
    printf "check options AND script has to be run on CEPH monitor - use carefully!\n"
    usage
    exit $NOK
fi

opts=$(getopt -q -o d:t:o:r:h --longoptions "directory:,threads:,oltp:,resultdir:,cpuprime:,maxreq:,testtype:,help" -n "getopt.sh" -- "$@");
eval set -- "$opts";
echo "processing options"
while true; do
    case "$1" in
        -d|--directory)
            shift;
            if [ -n "$1" ]; then
                DB_DIR="$1"
                shift;
            fi
        ;;
        -t|--threads)
            shift;
            if [ -n "$1" ]; then
                THREADS="$1"
                shift;
            fi
        ;;
        -o|--oltp)
            shift;
            if [ -n "$1" ]; then
                oltp="$1"
                shift;
            fi
        ;;
        -r|--resultdir)
            shift;
            if [ -n "$1" ]; then
                resultdir="$1"
                shift;
            fi
        ;;
        --cpuprime)
            shift;
            if [ -n "$1" ]; then
                cpuprime="$1"
                shift;
            fi
        ;;
        --maxreq)
            shift;
            if [ -n "$1" ]; then
                maxreq="$1"
                shift;
            fi
        ;;
        --testtype)
            shift;
            if [ -n "$1" ]; then
                testtype="$1"
                shift;
            fi
        ;;
        -h|--help)
            usage
        ;;
        --)
            shift
            break;
        ;;
        *)
            shift;
            break;
    esac
done

# start mariadb

start_oltp_test () {

    mkdir -p $DB_DIR/data
    mkdir -p $DB_DIR/datalog
    pkill mysqld_safe
    sed -i 's/pid\-file\=\/var\/run\/mariadb\/mariadb\.pid/pid\-file\=\/root\/mariadb\.pid/g' $MARIADBCONF
    echo "starting myslq..."
    mysqld_safe --user=root --basedir=/usr --skip-grant-tables --innodb_data_home_dir=$DB_DIR/data \
            --innodb_log_group_home_dir=$DB_DIR/datalog --innodb_log_buffer_size=64M \
            --innodb_thread_concurrency=0 --max_connections=1000 --table_cache=4096 --innodb_flush_method=O_DIRECT &

    sleep 30
    printf "Prepare sysbench environment and set up mariadb user\n"
    if [ ! -e /root/mariadb.pid ]; then
        sleep 30
    fi
    mysqladmin -f -uroot -pmysqlpass drop sbtest
    mysqladmin -uroot -pmysqlpass create sbtest
    $sysbench_bin --test=/sysbench-0.5/sysbench/tests/db/oltp.lua --oltp-table-size=$oltp --mysql-db=sbtest --mysql-user=root --mysql-password=mysqlpass prepare

    printf "Running SYSBENCH OLTP test for $THREADS threads\n"
    for numthread in $(echo $THREADS | sed -e s/,/" "/g); do
        mkdir -p "$resultdir"/$(hostname -s)
        printf "Running test with $numthread sysbench threads\n"
        $sysbench_bin run --test=/sysbench-0.5/sysbench/tests/db/oltp.lua --num-threads="$numthread" --mysql-table-engine=innodb --mysql-user=root --mysql-password=mysqlpass --oltp-table-size="$oltp" --max-time=1800 --max-requests="$maxreq" >> $resultdir/$(hostname -s)/sysbench_oltp_test_$DATE.txt
        printf "Successfully finished OLTP sysbench test for $numthread threads\n"
    done
}

start_cpu_test() {
    printf "Running SYSBENCH CPU test for $THREADS threads\n"
    for numthread in $(echo $THREADS | sed -e s/,/" "/g); do
        mkdir -p $resultdir/$(hostname -s)
        $sysbench_bin --test=cpu --cpu-max-prime="$cpuprime" --num-threads="$numthread" run >> "$resultdir"/$(hostname -s)/sysbench_cpu_test_$DATE.txt
        printf "Successfully finished CPU sysbench test for $numthread threads\n"
    done
}

# run test

if [ "$testtype" == "oltp" ]; then
    start_oltp_test
elif [ "$testtype" == "cpu" ]; then
    start_cpu_test
elif [ "$testtype" == "oltpcpu" ]; then
    start_oltp_test
    start_cpu_test
fi
