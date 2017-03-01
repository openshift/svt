#!/bin/bash

exitstatus=0

PARALLEL_NODES=5
PARALLEL_TESTS="EmptyDir|Conformance"
PARALLEL_SKIP="Serial|Flaky|Disruptive|Slow"

SERIAL_TESTS="Serial"
SERIAL_SKIP="Flaky|Disruptive|Slow" 

cd
yum install atomic-openshift-tests
mkdir /root/go
export GOPATH=/root/go
export PATH=$PATH:$GOPATH/bin
go get github.com/onsi/ginkgo/ginkgo
git clone --depth=1 https://github.com/openshift/origin
cd origin/test
export KUBECONFIG=/etc/origin/master/admin.kubeconfig
export KUBE_REPO_ROOT=/root/origin/vendor/k8s.io/kubernetes
export EXTENDED_TEST_PATH=/root/origin/test/extended


TEST_REPORT_DIR=/tmp TEST_REPORT_FILE_NAME=svt-parallel ginkgo --noColor -v "-focus=$PARALLEL_TESTS" "-skip=$PARALLEL_SKIP" -p -nodes "$PARALLEL_NODES"  /usr/libexec/atomic-openshift/extended.test  || exitstatus=$?
#TEST_REPORT_DIR=/tmp TEST_REPORT_FILE_NAME=svt-serial ginkgo --noColor -v "-focus=$SERIAL_TESTS" "-skip=$SERIAL_SKIP" /usr/libexec/atomic-openshift/extended.test  || exitstatus=$?
 
