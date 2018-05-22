#!/bin/bash

SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`

exitstatus=0

PARALLEL_NODES=5
PARALLEL_TESTS="EmptyDir|Conformance"
PARALLEL_SKIP="Serial|Flaky|Disruptive|Slow|should be applied to XFS filesystem when a pod is created"
echo $PARALLEL_SKIP
SERIAL_TESTS="Serial"
SERIAL_SKIP="Flaky|Disruptive|Slow"

setup_prereqs() {
   yum -y install go atomic-openshift-tests
   mkdir /root/go
   export GOPATH=/root/go
   export PATH=$PATH:$GOPATH/bin
   go get github.com/onsi/ginkgo/ginkgo

}

import_wildfly() {

   # create wildfly imagestream
   cd $SCRIPTPATH
   oc create -n openshift -f ./wildfly_imagestream.json

}

fix_jenkins() {
   oc get -n openshift -o yaml is jenkins > /tmp/jenkins.yaml
   sed -i.orig 's/jenkins-2-rhel7:v3.10/jenkins-2-rhel7:latest/g' /tmp/jenkins.yaml
   oc replace --namespace=openshift -f /tmp/jenkins.yaml
}

remove_default_node_selector() {
	ansible-playbook -i $SCRIPTPATH/masters $SCRIPTPATH/removeNodeSelector.yaml
}

restore_default_node_selector() {
	ansible-playbook -i $SCRIPTPATH/masters $SCRIPTPATH/restoreNodeSelector.yaml
}

create_master_inventory() {
	oc get nodes --no-headers -l node-role.kubernetes.io/master=true | cut -f1 -d" " > $SCRIPTPATH/masters
}

export KUBECONFIG=/etc/origin/master/admin.kubeconfig
cd

setup_prereqs

import_wildfly
fix_jenkins

create_master_inventory
remove_default_node_selector

TEST_REPORT_DIR=/tmp TEST_REPORT_FILE_NAME=svt-parallel ginkgo -v "-focus=$PARALLEL_TESTS" "-skip=$PARALLEL_SKIP" -p -nodes "$PARALLEL_NODES"  /usr/libexec/atomic-openshift/extended.test  || exitstatus=$?
#TEST_REPORT_DIR=/tmp TEST_REPORT_FILE_NAME=svt-serial ginkgo -v "-focus=$SERIAL_TESTS" "-skip=$SERIAL_SKIP" /usr/libexec/atomic-openshift/extended.test  || exitstatus=$?

restore_default_node_selector
echo "exitstatus="$exitstatus
exit $exitstatus
