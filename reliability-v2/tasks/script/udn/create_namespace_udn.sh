#!/bin/bash
################################################
## Author: qili@redhat.com
## Description: Script for creating udn namespace and apply udn. Udn namespace needs a label k8s.ovn.org/primary-user-defined-network:"". 
## There is a bug the udn namespace can not be created by 'oc create namespace'. It can only be created by yaml file for now.
################################################

USER=${USER:-""}
GROUP=${GROUPNAME:-""}
SCRIPT_DIR="$(dirname "$0")"
namespace_template="${SCRIPT_DIR}/udn_namespace.yaml"
udn_l3=${UDN:-"${SCRIPT_DIR}/udn_l3.yaml"}
udn_l2=${UDN:-"${SCRIPT_DIR}/udn_l2.yaml"}

function usage {
    echo "Usage: $(basename "${0}") -n <number of namespaces> -l <layer>"
    echo "-n <number_of_namespace>     : Number of namespaced to be created under a user. Default is 1."
    echo "-l <layer>                   : Network layers. 2 or 3. Default is 3."
    echo "-h                           : Help"
}

while getopts ":n:l:h" opt; do
    case ${opt} in
    n)
        user_number=${OPTARG}
        ;;
    l)  layer=${OPTARG}
        ;;
    h)
        usage
        exit 1
        ;;
    \?)
        echo -e "\033[32mERROR: Invalid option -${OPTARG}\033[0m" >&2
        usage
        exit 1
        ;;
    :)
        echo -e "\033[32mERROR: Option -${OPTARG} requires an argument.\033[0m" >&2
        usage
        exit 1
        ;;
    esac
done

function get_os {
    if [[ $(uname -a) =~ "Darwin" ]]; then 
        os=mac
    else
        os=linux
    fi
}

if [[ "$1" = "" ]];then
    usage
    exit 1
fi
get_os
[[ -z ${user_number} ]] && user_number=1
if [[ ${layer} = 2 ]]; then
    udn=${udn_l2}
else
    udn=${udn_l3}
fi
for (( i=0; i<${user_number}; i++ ))
do
    namespace_name="${GROUP}-${USER}-${i}"
    temp_file=udn_namespace_${namespace_name}.yaml
    cp ${namespace_template} ${temp_file}
    if [[ $os == "linux" ]]; then
        sed -i s*'<namespace_name>'*${namespace_name}* ${temp_file}
    elif [[ $os == "mac" ]]; then
        sed -i "" s*'<namespace_name>'*${namespace_name}* ${temp_file}
    fi
    echo "creating namespace ${namespace_name}"
    oc apply -f ${temp_file}
    rm ${temp_file}
    echo "get namespace ${namespace_name}"
    oc get ns ${namespace_name}
    oc apply -f ${udn} -n ${namespace_name}
    echo "get udn in namespace ${namespace_name}"
    oc get userdefinednetwork -n ${namespace_name}
done
