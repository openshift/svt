#/!/bin/bash
##################################################################################################
## Auth=qili@redhat.com
## Desription: Script for lws scale test
## Polarion test case: 
## Document: https://docs.google.com/document/d/10KMijkR6ddBX0jIdZLAXdViE_Pny28UolmxWvrtS0xE/
## Pre-requisites: 
### Cluster with 3 master nodes and 24 m5.xlarge worker cluster on AWS
## Parameters: IMAGE REPLICAS
###################################################################################################


# If parameters is set from upstream ci, overwrite params
echo "Upstream PARAMETERS set to $PARAMETERS"
export params=(${PARAMETERS:-2 700})
echo "params is $params"

export REPLICAS=${params[0]:-"2"}
export SIZE=${params[1]:-"700"}
export OPERATOR_IMAGE=${params[2]:-"registry.redhat.io/leader-worker-set/lws-rhel9-operator@sha256:c202bfa15626262ff22682b64ac57539d28dd35f5960c490f5afea75cef34309"}
export OPERAND_IMAGE=${params[3]:-"registry.redhat.io/leader-worker-set/lws-rhel9@sha256:affb303b1173c273231bb50fef07310b0e220d2f08bfc0aa5912d0825e3e0d4f"}

echo "Testing with workload $WORKLOAD, replicas $REPLICAS, size $SIZE."

# Install dittybopper to check resource usage
# install_dittybopper

# Install cert-manager
VERSION=v1.17.0
oc apply -f https://github.com/cert-manager/cert-manager/releases/download/$VERSION/cert-manager.yaml
oc -n cert-manager wait --for condition=ready pod -l app.kubernetes.io/instance=cert-manager --timeout=2m

echo "clone the lws-operator repo"
git clone https://github.com/openshift/lws-operator.git
pushd lws-operator
echo "replace images"
envsubst < deploy/05_deployment.yaml > deploy/05_deployment.yaml.tmp
mv deploy/05_deployment.yaml.tmp deploy/05_deployment.yaml
cat deploy/05_deployment.yaml

echo "deploy the operator"
oc apply -f deploy/

# to avoid the error
# error: resource mapping not found for name: "cluster" namespace: "" from "deploy/07_lws-operator.cr.yaml": no matches for kind "LeaderWorkerSetOperator" in version "operator.openshift.io/v1"
if [[ $? -ne 0 ]]; then
    sleep 10
    oc apply -f deploy/
fi
popd

# sleep 120s to wait for the crd to be created
sleep 120
oc get crd |grep -i leaderworkerset

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# apply lws
bash -x ${SCRIPT_DIR}/lws-test.sh -r $REPLICAS -s $SIZE