# OpenShift System Test conformance test wrapper

## Environment
This project is an initial attempt to run a subset of the Kubernetes and OpenShift tests in system test clusters.   The upstream tests often make assumptions about the environment they are running in, so some configuration work is required to maximize the number of passing tests.

1. Install an OpenShift V3 cluster
2. Install the additional **atomic-openshift-tests** rpm.
3. git clone https://github.com/openshift/origin 
4. export EXTENDED\_TEST\_PATH=__origin-dir__/test/extended  (e.g. /root/origin/test/extended)
5. export KUBE\_REPO\_ROOT=__origin-dir__/kubernetes  (e.g. /root/origin/kubernetes)
6. export KUBERNETES_PROVIDER=aws (only AWS has been tested so far)
7. export KUBECONFIG=/etc/origin/master/admin.kubeconfig (if running on master) or ~/.kube/config (if running on client)
8. go get github.com/onsi/ginkgo/ginkgo
9. export PATH=$PATH:$GOPATH/bin

## Cluster configuration

The OpenShift tests create many temporary users.  For these tests to pass, the OpenShift [AllowPasswordIdentityProvider](https://docs.openshift.org/latest/install_config/configuring_authentication.html#AllowAllPasswordIdentityProvider) should be used for the duration of the tests.   Don't forget to change it back if cluster security is required.

The Kubernetes resource and density tests assume all nodes are schedulable.  For these tests to pass the OpenShift master nodes should be set to [schedulable](https://docs.openshift.org/latest/admin_guide/manage_nodes.html#marking-nodes-as-unschedulable-or-schedulable).


## Running the tests

After the above steps are complete, run ./svt_conformance.sh.   The report will be written to /tmp.  Or you can modify the TEST_REPORT_DIR and TEST_REPORT_FILE_NAME environment variables to modify the location.  This is an area that still needs some work to make it more configurable.


## Work in progress!

These tests are a work in progress.

Feedback, issues and pull requests happily accepted!
