#!/usr/bin/env bash
# default docker storage backed when used with openshift will be loop-lvm what is not optimal
# this script accepts vg or device you want to use for custom vg/device for docker storage setup"
# it will write /etc/sysconfig/docker-storage-setup and that configuration will be then used by docker-storage-setup script
# Author : ekuric@redhat.com
# License : GPL{2|3}

usage() {
    printf "Usage: $(basename $0) -s|--storage <d|v|n> -d <sdX> -v <myvg> \n"
    printf "Case 1: custom vg : $(basename $0) -s|--storage <v|vgroup> -v <myvg>\n"
    printf "Case 2: custom device : $(basename $0) -s|--storage <d|device> -d <sdX>\n"
    printf "Case 3: leave to default - if there is free space on root vg - thin lvm will be created using free space on root vg,otherwise loop lvm will be used\n"
    printf "Case 3: default: $(basename $0) -s|--storage -n|--none \n"
    exit 0
}

if [ "$#" -eq 0 ] || [ "$EUID" -ne 0 ]; then
    printf "Check options, also you have to be root to run this script\n"
    usage
    exit 1
fi

opts=$(getopt -q -o s:d:v:h --longoptions "storage:,device:,vgroup:,none,help" -n "getopt.sh" -- "$@");
eval set -- "$opts";
echo "processing options"
while true; do
    case "$1" in
        -s|--storage)
            shift;
            if [ -n "$1" ]; then
                storage="$1"
		        shift;
            fi
        ;;
        -d|--device)
            shift;
            if [ -n "$1" ]; then
                device="$1"
                shift;
            fi
        ;;
        -v|--vgroup)
            shift;
            if [ -n "$1" ]; then
                vgroup="$1"
                shift;
            fi
        ;;
        -h|--help)
            shift;
            if [ -n "$1" ]; then
                help="$1"
                usage
            fi
        ;;
        --)
            shift;
            printf "Check options\n"
            break;
        ;;
        *)
            shift;
            break;
        ;;
    esac
done

case "$storage" in
    d|device)
cat <<EOF > /etc/sysconfig/docker-storage-setup
DEVS=/dev/$device
VG=docker_vg_$device 
EOF
    printf "We will use custom volume group docker_vg_$device which will use custom block device $device\n"
    printf "If volume group is not created -- ensure $device has not fs signatures / partitions and rerun script\n"
    ;;
    v|vgroup)
    printf "You selected option to create docker storage on volume group $vgroup - ensure it exist on system\n"
cat <<EOF > /etc/sysconfig/docker-storage-setup
VG=$vgroup
EOF
    ;;
    n|none)
        printf "default - loop lvm will be used - if there is free space on root VG, it will be used to crate thin lvm\n"
        printf "This is not production supported\n"
cat <<EOF > /etc/sysconfig/docker-storage-setup
#This is default configuration/usr/lib/docker-storage-setup/docker-storage-setup.
# check /usr/lib/docker-storage-setup/docker-storage-setup for example configuration
# For more details refer to "man docker-storage-setup"
EOF
    ;;
esac
