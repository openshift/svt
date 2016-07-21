#!/bin/bash

readonly EXCLUDED_TESTS=(
  "\[Skipped\]"
  "\[Disruptive\]"
  "\[Slow\]"
  "\[Flaky\]"

  "\[Feature:Performance\]"

  # Depends on external components, may not need yet
  Monitoring              # Not installed, should be
  "Cluster level logging" # Not installed yet
  Kibana                  # Not installed
  Ubernetes               # Can't set zone labels today
  kube-ui                 # Not installed by default
  "^Kubernetes Dashboard"  # Not installed by default (also probbaly slow image pull)

        # deployments are not yet enabled
  "Deployment deployment"
  "Deployment paused deployment"
  "paused deployment should be ignored by the controller"
  "deployment should create new pods"
        "should create an rc or deployment from an image"
        "should create a deployment from an image"
  "RollingUpdateDeployment should scale up and down in the right order"
  "RollingUpdateDeployment should delete old pods and create new ones"
  "RecreateDeployment should delete old pods and create new ones"

  Ingress                 # Not enabled yet
  "should proxy to cadvisor" # we don't expose cAdvisor port directly for security reasons
  "Cinder"                # requires an OpenStack cluster
  "should support r/w"    # hostPath: This test  expects that host's tmp dir is WRITABLE by a container.  That isn't something we need to gaurantee for openshift.
  "should check that the kubernetes-dashboard instance is alive" # we don't create this
  "\[Feature:ManualPerformance\]" # requires /resetMetrics which we don't expose

  # See the CanSupport implementation in upstream to determine wether these work.
  "Ceph RBD"      # Works if ceph-common Binary installed (but we can't gaurantee this on all clusters).
  "GlusterFS" # May work if /sbin/mount.glusterfs to be installed for plugin to work (also possibly blocked by serial pulling)
  "should support r/w" # hostPath: This test expects that host's tmp dir is WRITABLE by a container.  That isn't something we need to guarantee for openshift.

  "should allow starting 95 pods per node" # needs cherry-pick of https://github.com/kubernetes/kubernetes/pull/23945

  # Need fixing
  "Horizontal pod autoscaling" # needs heapster
  "should provide Internet connection for containers" # Needs recursive DNS
  PersistentVolume           # https://github.com/openshift/origin/pull/6884 for recycler
  "mount an API token into pods" # We add 6 secrets, not 1
  "ServiceAccounts should ensure a single API token exists" # We create lots of secrets
  "Networking should function for intra-pod" # Needs two nodes, add equiv test for 1 node, then use networking suite
  "should test kube-proxy"   # needs 2 nodes
  "authentication: OpenLDAP" # needs separate setup and bucketing for openldap bootstrapping
  "should support exec through an HTTP proxy" # doesn't work because it requires a) static binary b) linux c) kubectl, https://github.com/openshift/origin/issues/7097
  "NFS"                      # no permissions https://github.com/openshift/origin/pull/6884
  "\[Feature:Example\]"      # may need to pre-pull images
  "should serve a basic image on each replica with a public image" # is failing to create pods, the test is broken

  # Needs triage to determine why it is failing
  "Addon update"          # TRIAGE
  SSH                     # TRIAGE
  "\[Feature:Upgrade\]"   # TRIAGE
  "SELinux relabeling"    # started failing
  "schedule jobs on pod slaves use of jenkins with kubernetes plugin by creating slave from existing builder and adding it to Jenkins master" # https://github.com/openshift/origin/issues/7619
  "openshift mongodb replication creating from a template" # flaking on deployment
  "Update Demo should do a rolling update of a replication controller" # this is flaky and needs triaging

  # Inordinately slow tests
  "should create and stop a working application"
  "should always delete fast" # will be uncommented in etcd3
  
  #SVT excludes
  "should create and run a job in user project" #yaml input does not exist
  "should be applied to XFS filesystem when a pod is created" #requires VOLUME_DIR set up with XFS fx.  need to investigate
  "should provide DNS for the cluster" # requires k8s DNS pod 
  "should provide DNS for services" # requires k8s DNS pod 
  "should support subPath"  # does not work with selinux-enabled
  "should propagate requested groups to the docker host config" #need to investigate - believe it requires Docker running locally"

)

readonly SERIAL_TESTS=(
  "\[Serial\]"
  "\[Feature:ManualPerformance\]" # requires isolation
  "Service endpoints latency" # requires low latency
  "\[Feature:HighDensityPerformance\]" # requires no other namespaces
)

readonly CONFORMANCE_TESTS=(
  "\[Conformance\]"

  "Services.*NodePort"
  "ResourceQuota should"
  "\[networking\] basic openshift networking"
  "\[networking\]\[router\]"
  "Ensure supplemental groups propagate to docker"
  "EmptyDir"
  "PrivilegedPod should test privileged pod"
  "Pods should support remote command execution"
  "Pods should support retrieving logs from the container"
  "Kubectl client Simple pod should support"
  "Job should run a job to completion when tasks succeed"
  "\[images\]\[mongodb\] openshift mongodb replication"
  "\[job\] openshift can execute jobs controller"
  "\[volumes\] Test local storage quota FSGroup"
  "test deployment should run a deployment to completion"
  "Variable Expansion"
  "Clean up pods on node kubelet"
  "\[Feature\:SecurityContext\]"
  "should create a LimitRange with defaults"
  "Generated release_1_2 clientset"
)

function join { local IFS="$1"; shift; echo "$*"; }

export KUBECONFIG=${KUBECONFIG:-/etc/origin/master/admin.kubeconfig}
export KUBERNETES_PROVIDER=${KUBERNETES_PROVIDER:-aws}
export KUBE_REPO_ROOT=${KUBE_REPO_ROOT_PATH:-/root/kubernetes}
export EXTENDED_TEST_PATH=${EXTENDED_TEST_PATH:-/root/origin/test/extended}

svt_exclude=( "${EXCLUDED_TESTS[@]}" )
svt_tests=( "${CONFORMANCE_TESTS[@]}" "${SERIAL_TESTS[@]}")
svt_focus=$(join '|' "${svt_tests[@]}")
svt_skip=$(join '|' "${svt_exclude[@]}")

#Running SVT
#TEST_REPORT_DIR= TEST_OUTPUT_QUIET=true /usr/libexec/atomic-openshift/extended.test "--ginkgo.focus=${svt_focus}" "--ginkgo.skip=${svt_skip}" --ginkgo.dryRun --ginkgo.noColor | grep ok | grep -v skip | cut -c 20- | sort
#TEST_REPORT_DIR=/root/test1 ginkgo -v "-focus=docker build using a pull secret Building from a template should create a docker build that pulls using a secret run it" /usr/libexec/atomic-openshift/extended.test -- -ginkgo.v


parallel_only=( "${CONFORMANCE_TESTS[@]}" )
parallel_exclude=( "${EXCLUDED_TESTS[@]}" "${SERIAL_TESTS[@]}" )
serial_only=( "${SERIAL_TESTS[@]}" )
serial_exclude=( "${EXCLUDED_TESTS[@]}" )

pf=$(join '|' "${parallel_only[@]}")
ps=$(join '|' "${parallel_exclude[@]}")
sf=$(join '|' "${serial_only[@]}")
ss=$(join '|' "${serial_exclude[@]}")

#echo "[INFO] Running the following tests:"
#TEST_REPORT_DIR= TEST_OUTPUT_QUIET=true /usr/libexec/atomic-openshift/extended.test "--ginkgo.focus=${pf}" "--ginkgo.skip=${ps}" --ginkgo.dryRun --ginkgo.noColor | grep ok | grep -v skip | cut -c 20- | sort
#TEST_REPORT_DIR= TEST_OUTPUT_QUIET=true /usr/libexec/atomic-openshift/extended.test "--ginkgo.focus=${sf}" "--ginkgo.skip=${ss}" --ginkgo.dryRun --ginkgo.noColor | grep ok | grep -v skip | cut -c 20- | sort
#echo
 
exitstatus=0
 
# Running Openshift
# run parallel tests
#nodes="${PARALLEL_NODES:-5}"
#echo "[INFO] Running parallel tests N=${nodes}"

TEST_REPORT_DIR=/tmp TEST_REPORT_FILE_NAME=svt-par ginkgo -v "-focus=${pf}" "-skip=${ps}" -p -nodes "5"  /usr/libexec/atomic-openshift/extended.test -- -ginkgo.v -test.timeout 6h || exitstatus=$?
 
# run tests in serial
#echo "[INFO] Running serial tests"
TEST_REPORT_DIR=/tmp TEST_REPORT_FILE_NAME=svt-ser ginkgo -v "-focus=${sf}" "-skip=${ss}" /usr/libexec/atomic-openshift/extended.test -- -ginkgo.v -test.timeout 2h || exitstatus=$?
