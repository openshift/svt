#!/usr/bin/env bash
#
# Sets up logging from scratch based on the local openshift-ansible template.
#
# To create from the latest template:
# oc create -n openshift -f \
# https://raw.githubusercontent.com/openshift/origin-aggregated-logging/master/deployer/deployer.yaml &> /dev/null
#
# It's safe to ignore any warnings/errors about already existing API types or resources (roles/templates etc...)
#

if [[ `id -u` -ne 0 ]]
then
        echo -e "\n[-] Please run as root / sudo -s \n"
        echo -e "Exit."
        exit 1
fi

if [ $# -eq 2 ]
  then
    :
  else
    echo -e "\nTwo arguments reguired. Check /etc/origin/master/master-config.yaml"
    echo "1) https://MASTER_URL:8443"
    echo "2) https://PUBLIC_MASTER_URL:8443"
    echo
    echo "Example:"
    echo "MU=https://ip-xxx-xx-xx-xxx.us-xxxx-x.compute.internal:8443"
    echo "PMU=https://ec2-xx-xxx-xxx-xxx.us-xxxx-x.compute.amazonaws.com:8443"
    echo
    echo "./$(basename $0)" '$MU' '$PMU'
    echo
    exit 1
fi

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OSEANSIBLE=$HOME/openshift-ansible

# local ose-ansible template install
if [[ ! -d $OSEANSIBLE ]]; then
  echo -e "\n[-] Cloning the openshift-ansible git repo first."
  echo
  cd $HOME && git clone https://github.com/openshift/openshift-ansible && cd -
  echo "Done. Resuming..."
fi

function _wait() {
        echo -e "\nSleeping for $1 secs..."
        sleep $1
        echo -e "Resuming...\n"
}

function add_roles() {
        oc policy add-role-to-user edit --serviceaccount logging-deployer
        oc policy add-role-to-user daemonset-admin --serviceaccount logging-deployer
        oadm policy add-cluster-role-to-user oauth-editor system:serviceaccount:logging:logging-deployer
        oadm policy add-scc-to-user privileged system:serviceaccount:logging:aggregated-logging-fluentd
        oadm policy add-cluster-role-to-user cluster-reader system:serviceaccount:logging:aggregated-logging-fluentd
}

function pre_clean() {
        # logging-deployer-template and logging-deployer-account-template should
	# already exist under the openshift namespace. Delete them first.
        oc delete project logging &> /dev/null
        for template in 'logging-deployer-template' 'logging-deployer-account-template'
        do
          oc delete template $template -n openshift &> /dev/null
        done
}

function tear_down() {
        oc delete all --selector logging-infra=kibana
        oc delete all,daemonsets --selector logging-infra=fluentd
        oc delete all --selector logging-infra=elasticsearch
        oc delete all --selector logging-infra=curator
        oc delete all,sa,oauthclient --selector logging-infra=support

        oc delete secret logging-fluentd logging-elasticsearch \
        logging-es-proxy logging-kibana logging-kibana-proxy \
        logging-kibana-ops-proxy
}

T=20
MASTER_URL=${1:-"https://MASTER_URL:8443"}
PUBLIC_MASTER_URL=${2:-"https://PUBLIC_MASTER_URL:8443"}
CLUSTER_SIZE=${3:-"1"}

echo -e "\n\n[+] Setting up EFK Logging.\n"
echo
echo "MASTER_URL: $MASTER_URL"
echo "PUBLIC_MASTER_URL: $PUBLIC_MASTER_URL"
echo "CLUSTER_SIZE: $CLUSTER_SIZE"

pre_clean

_wait $T

oadm new-project logging --node-selector=""
oc project logging

# create from the local template for now
oc create -f ${OSEANSIBLE}/roles/openshift_examples/files/examples/v1.2/infrastructure-templates/origin/logging-deployer.yaml

# the logging pod will try to mount the secrets below
oc delete secret logging-deployer &> /dev/null
oc secrets new logging-deployer nothing=/dev/null

oc new-app logging-deployer-account-template

_wait $T

echo -e "\nAdding required roles"
add_roles

oc delete oauthclient kibana-proxy
oc new-app logging-deployer-template \
                        --param ES_CLUSTER_SIZE=$CLUSTER_SIZE \
                        --param PUBLIC_MASTER_URL=$PUBLIC_MASTER_URL \
                        --param MASTER_URL=$MASTER_URL

_wait $T

# fluentd pod spreading
oc label nodes --all logging-infra-fluentd=true &> /dev/null

echo

cat << EOF
[+] Check your logging project with these commands:

oc get dc --selector logging-infra=elasticsearch
oc get pods --selector='component=es'
oc get pods --selector='component=kibana'
oc get pods --selector='component=fluentd'

oc get all
EOF
