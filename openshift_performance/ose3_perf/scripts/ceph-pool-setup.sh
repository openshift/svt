#!/usr/bin/env bash

# script to setup ceph pool and rbd images on top of ceph pool

# defaults
NOK=1
# by default we will insist on 3-way replica for CEPH pool
REPLICA=3
# number of OSDs in CEPH cluster
OSDNUM=$(ceph osd stat | awk '{print $3}')

usage() {
        printf  "Usage: ./$(basename $0) -p pname -i inum -r replica -s isize\n"
        printf -- "-a action: what to do it can be c|create - create the ceph pool, or d|delete - delete the ceph pool\n"
        printf -- "-p pname : ceph pool name\n"
        printf -- "-i inum : how many images to create on top of pool\n"
        printf -- "-r replica: ceph pool replica mode - if not specified default replica=3 for ceph pool will be used\n"
        printf -- "-s -isize: image size - the value is in MB\n"
        exit 0
}

if [ "$EUID" -ne 0 ] || [ "$#" -eq 0 ] ; then
    printf "Necessary to be root to run script and necessary to provide script parameters\n"
    printf "check options AND script has to be run on CEPH monitor - use carefully!\n"
    usage
    exit $NOK
fi

opts=$(getopt -q -o a:p:i:s:r:h --longoptions "action:,pname:,inum:,isize:,replica:,help" -n "getopt.sh" -- "$@");
eval set -- "$opts";
echo "processing options"
while true; do
    case "$1" in
        -p|--pname)
            shift;
            if [ -n "$1" ]; then
                pname="$1"
                shift;
            fi
        ;;
        -i|--inum)
            shift;
            if [ -n "$1" ]; then
                inum="$1"
                shift;
            fi
        ;;
        -s|--isize)
            shift;
            if [ -n "$1" ]; then
                isize="$1"
                shift;
            fi
        ;;
        -r|--replica)
            shift;
            if [ -n "$1" ]; then
                REPLICA="$1"
                shift;
            fi
        ;;
        -a|--action)
            shift;
            if [ -n "$1" ]; then
                action="$1"
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

create_ceph_pool() {
    local imagenum=0
    # it is recommended to keep PG ( placemenet groups ) equeal to PGP placement groups for placement
    local PG_NUM=$(($OSDNUM*100/$REPLICA))
    local PGP_NUM=$(($OSDNUM*100/$REPLICA))
    ceph osd pool create $pname $PG_NUM $PGP_NUM
    ceph osd pool set $pname size $REPLICA

    # create images on ceph pool
    while [ $imagenum -le $inum ] ; do
        rbd create image$imagenum --size $isize --pool $pname
        imagenum=$[$imagenum+1]
    done

    # list pools
    printf "Images created on ceph pool: $pname are as showed below\n"
    rbd ls -l $pname
}

delete_pool() {
    if [ -z $pname ]; then
        printf "pool name not given ... check options : for pool delete necessarty to specify pool name\n"
        usage; exit 0
    elif [ -n $pname ]; then
        printf "Going to delete ceph pool: $pname\n"
        ceph osd pool delete $pname $pname --yes-i-really-really-mean-it
        printf "ceph pool: $pname is deleted\n"
    fi
}
# main
case "$action" in
    c|create)
        create_ceph_pool
    ;;
    d|delete)
        delete_pool
esac
