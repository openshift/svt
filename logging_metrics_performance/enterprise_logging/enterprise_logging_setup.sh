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

MASTERCFG=/etc/origin/master/master-config.yaml
VERSION="v1.2"

if [[ $1 =~ "auto" ]]
  then
    MASTER_URL=`grep masterURL $MASTERCFG | awk '{print $2}'`
    PUBLIC_MASTER_URL=`grep ^masterPublicURL $MASTERCFG | awk '{print $2}'`
  else
    if [[ ! $1 || ! $2 ]]; then
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
    MASTER_URL=$1
    PUBLIC_MASTER_URL=$2
fi

SCRIPTNAME=$(basename ${0%.*})
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTILS=$SCRIPTDIR/utils
source $UTILS/functions.sh
trap sig_handler SIGINT


T=20
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OSEANSIBLE=$HOME/openshift-ansible
TBASE=${OSEANSIBLE}/roles/openshift_examples/files/examples/${VERSION}/infrastructure-templates/enterprise
ANSIBLE_TEMPLATE=${TBASE}/logging-deployer.yaml

# local ose-ansible template install
if [[ ! -d $OSEANSIBLE ]]; then
  echo -e "\n[-] Cloning the openshift-ansible git repo first."
  echo
  cd $HOME && git clone https://github.com/openshift/openshift-ansible && cd -
  echo "Done. Resuming..."
fi


CLUSTER_SIZE=${3:-3}
KIBANA_HOSTNAME=${4:-kibana.example.com}

echo -e "\n\n[+] Setting up EFK Logging.\n"
echo
echo "MASTER_URL: $MASTER_URL"
echo "PUBLIC_MASTER_URL: $PUBLIC_MASTER_URL"
echo "CLUSTER_SIZE: $CLUSTER_SIZE"
echo "KIBANA_HOSTNAME: $KIBANA_HOSTNAME"
echo "ANSIBLE_TEMPLATE: $ANSIBLE_TEMPLATE"

pre_clean
_wait $T

oadm new-project logging --node-selector=""
oc project logging


# wget latest and create from the local template
# openshift-ansible/roles/openshift_examples/examples-sync.sh
wget https://raw.githubusercontent.com/openshift/origin-aggregated-logging/enterprise/deployment/deployer.yaml -O ${ANSIBLE_TEMPLATE}
sed -i 's/imagePullPolicy: Always/imagePullPolicy: IfNotPresent/g' ${ANSIBLE_TEMPLATE}
oc create -f ${ANSIBLE_TEMPLATE}


# the logging pod will try to mount the secrets below
oc delete secret logging-deployer &> /dev/null
oc secrets new logging-deployer nothing=/dev/null

oc new-app logging-deployer-account-template
_wait $T

echo -e "\nAdding required roles"
add_roles


oc delete oauthclient kibana-proxy &> /dev/null
oc new-app logging-deployer-template \
                        --param ES_CLUSTER_SIZE=$CLUSTER_SIZE \
                        --param PUBLIC_MASTER_URL=$PUBLIC_MASTER_URL \
                        --param MASTER_URL=$MASTER_URL \
			--param KIBANA_HOSTNAME=$KIBANA_HOSTNAME

_wait $T


# fluentd pod spreading
# in large clusters this can be adjusted to label certain nodes only
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

exit $OK
