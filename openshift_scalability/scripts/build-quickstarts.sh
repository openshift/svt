#!/bin/bash


# Script to build quickstart applications in the 'openshift' namespace

set -o errexit
set -o nounset
set -o pipefail

# this script is in svt/openshift_scalability/scripts
CLUSTER_LOADER_DIR=$(dirname ${BASH_SOURCE})/..
CONTENT_DIR=${CLUSTER_LOADER_DIR}/content/quickstarts

# names of quickstart app directories in svt/openshift_scalability/content
QUICKSTART_APPS_DIRS="\
cakephp \
dancer \
django \
eap \
nodejs \
rails \
tomcat \
"

# processes/creates all build templates in the specified app directories
for app_dir in ${QUICKSTART_APPS_DIRS}; do
    BUILD_TEMPLATES=$(ls ${CONTENT_DIR}/${app_dir} | grep build)

    for template in ${BUILD_TEMPLATES}; do
	oc process -f ${CONTENT_DIR}/${app_dir}/$template | oc create --namespace openshift -f -
    done
done
