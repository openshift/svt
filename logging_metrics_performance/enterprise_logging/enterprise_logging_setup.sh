#!/usr/bin/env bash
#
# Sets up logging from scratch based on the local openshift-ansible template.
#
# It's safe to ignore any warnings/errors about already existing API types or resources (roles/templates etc...)
#

SCRIPTNAME=$(basename ${0%.*})
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTILS=$SCRIPTDIR/utils
source $UTILS/functions.sh
trap sig_handler SIGINT

if [[ `id -u` -ne 0 ]]
then
        echo -e "\n[-] Please run as root / sudo -s \n"
        echo -e "Exit."
        exit $ERR
fi

NUMARGS=$#
if [ $NUMARGS -eq 0 ]; then
    show_help
    exit $ERR;
fi

HELPER_CFG=$1
source $HELPER_CFG

# OCP
MASTERCFG=/etc/origin/master/master-config.yaml
MASTER_URL=`grep masterURL $MASTERCFG | awk '{print $2}'`
PUBLIC_MASTER_URL=`grep ^masterPublicURL $MASTERCFG | awk '{print $2}'`

DELAY=20
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Openshift ansible
OSEANSIBLE=$HOME/openshift-ansible
TBASE=${OSEANSIBLE}/roles/openshift_hosted_templates/files/${VERSION}/enterprise
ANSIBLE_TEMPLATE=${TBASE}/logging-deployer.yaml

if [[ ! -d $OSEANSIBLE ]]; then
  echo -e "\n[-] Cloning the openshift-ansible git repo first."
  echo
  cd $HOME && git clone https://github.com/openshift/openshift-ansible && cd -
  echo "Done. Resuming..."
fi


echo -e "\n\n[+] Setting up EFK Logging.\n"
echo
echo "MASTER_URL: $MASTER_URL"
echo "PUBLIC_MASTER_URL: $PUBLIC_MASTER_URL"
echo "CLUSTER_SIZE: $CLUSTER_SIZE"
echo "KIBANA_HOSTNAME: $KIBANA_HOSTNAME"
echo "ANSIBLE_TEMPLATE: $ANSIBLE_TEMPLATE"
echo "IMAGE_PREFIX: $IMAGE_PREFIX"
echo "IMAGE_VERSION: $IMAGE_VERSION"


pre_clean
_wait $DELAY

oadm new-project logging --node-selector=""
oc project logging


sed -i 's/imagePullPolicy: Always/imagePullPolicy: IfNotPresent/g' ${ANSIBLE_TEMPLATE}
oc create -f ${ANSIBLE_TEMPLATE}


# the logging pod will try to mount the secrets below
oc delete secret logging-deployer &> /dev/null
oc secrets new logging-deployer nothing=/dev/null

oc new-app logging-deployer-account-template
_wait $DELAY

echo -e "\nAdding required roles"
add_roles


oc delete oauthclient kibana-proxy &> /dev/null

# the below params are defined in the config file
oc new-app logging-deployer-template \
                        --param ES_CLUSTER_SIZE=$CLUSTER_SIZE \
                        --param PUBLIC_MASTER_URL=$PUBLIC_MASTER_URL \
                        --param MASTER_URL=$MASTER_URL \
                        --param KIBANA_HOSTNAME=$KIBANA_HOSTNAME \
                        --param IMAGE_PREFIX=$IMAGE_PREFIX \
                        --param IMAGE_VERSION=$IMAGE_VERSION

_wait $DELAY

# fluentd pod spreading
# on large clusters this should be adjusted to label in batches. 
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
