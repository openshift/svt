#!/bin/bash

### script to install logging stack: run on master node only
### 1. generate the inventory file
### 2. run the playbook using the generated inventory file

set -e

echo "test: $(date)"

readonly LOGGING_PROJECT="$(oc get project | cut -d " " -f1 | grep logging)"
if [[ ! ${LOGGING_PROJECT} == "logging" ]]; then
  # for now we do it manually
  # we can automate this if we feel secure enough
  echo "logging project does not exists, please created by 'oc adm new-project logging --node-selector=\"\"'"
  exit 1
fi

readonly SOURCE_FOLDER="$(dirname "$(readlink -f ${0})")"
readonly INV_TEMPLATE="${SOURCE_FOLDER}/inv_logging.template"
readonly INV_FILE="/tmp/inv_logging.file"

if [[ ! -f "${INV_TEMPLATE}" ]]; then
  echo "Inventory template file not found: ${INV_TEMPLATE}"
  exit 1
fi

cp -f "${INV_TEMPLATE}" "${INV_FILE}"

source ${SOURCE_FOLDER}/master_lib.sh

readonly APP_DNS=$(get_first "subdomain")

echo "APP_DNS=${APP_DNS}"
if [[ ! ${APP_DNS} == *".qe.rhcloud.com"* ]]; then
  echo "Wrong APP_DNS: ${APP_DNS}"
  exit 1
fi

readonly MASTER_PUBLIC_URL=$(get_first "masterPublicURL")

echo "MASTER_PUBLIC_URL=${MASTER_PUBLIC_URL}"
if [[ ! ${MASTER_PUBLIC_URL} == "http"* ]]; then
  echo "Wrong MASTER_PUBLIC_URL: ${MASTER_PUBLIC_URL}"
  exit 1
fi

readonly MASTER_URL=$(get_first "masterURL")

echo "MASTER_URL=${MASTER_URL}"
if [[ ! ${MASTER_URL} == "http"* ]]; then
  echo "Wrong MASTER_URL: ${MASTER_URL}"
  exit 1
fi

readonly IMAGE_VERSION=$(get_image_version)

echo "IMAGE_VERSION=${IMAGE_VERSION}"
if [[ ! ${IMAGE_VERSION} == "v"* ]]; then
  echo "Wrong IMAGE_VERSION: ${IMAGE_VERSION}"
  exit 1
fi

readonly MASTER_IP=$(get_ip)

echo "MASTER_IP=${MASTER_IP}"

sed -i -e "s#{{MASTER_IP}}#${MASTER_IP}#g" "${INV_FILE}"
sed -i -e "s#{{MASTER_PUBLIC_URL}}#${MASTER_PUBLIC_URL}#g" "${INV_FILE}"
sed -i -e "s#{{MASTER_URL}}#${MASTER_URL}#g" "${INV_FILE}"
sed -i -e "s#{{APP_DNS}}#${APP_DNS}#g" "${INV_FILE}"
sed -i -e "s#{{IMAGE_VERSION}}#${IMAGE_VERSION}#g" "${INV_FILE}"

echo "===Generated inventory file:==="
cat "${INV_FILE}"

echo "===Run installation playbook:==="
ansible-playbook -i "${INV_FILE}" /root/openshift-ansible/playbooks/byo/openshift-cluster/openshift-logging.yml