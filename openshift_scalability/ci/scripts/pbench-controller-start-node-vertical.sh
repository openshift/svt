#!/bin/bash 


# print usage and check number of arguments passed
if [ "$#" -lt 8 ]; then
  echo "Incorrect number of arguments $#, expecting 8:"
  echo "$0 with arguments: "
  echo "   1. MASTER_PUBLIC_DNS"
  echo "   2. STANDALONE_ETCDS_PRIVATE_DNS"
  echo "   3. PBENCH_COLLECTION_INTERVAL"
  echo "   4. PBENCH_RESULTS_DIR_NAME"
  echo "   5. CLUSTER_LOADER_CONFIG_FILE"
  echo "   6. WAIT_TIME_BEFORE_STOPPING_PBENCH"
  echo "   7. PBENCH_REGISTER"
  echo "   8. PBENCH_RESULTS_INTERNAL_HOSTANME"
  exit 0
fi

echo -e "\nCurrent environment variables:\n$(env)"
echo -e "\nCurrent bash shell options: $(echo $-)"

DEFAULT_COLLECTION_DURATION_SECS=10
DEFAULT_PBENCH_REGISTER=false

MASTER_PUBLIC_DNS=$1
STANDALONE_ETCDS_PRIVATE_DNS=$2
PBENCH_COLLECTION_INTERVAL=$3
PBENCH_RESULTS_DIR_NAME=$4
CLUSTER_LOADER_CONFIG_FILE=$5
WAIT_TIME_BEFORE_STOPPING_PBENCH=${6:-$DEFAULT_COLLECTION_DURATION_SECS}
PBENCH_REGISTER=${7:-$DEFAULT_PBENCH_REGISTER}
PBENCH_RESULTS_INTERNAL_URL_PREFIX=$8

echo "MASTER_PUBLIC_DNS from first argument: ${MASTER_PUBLIC_DNS}"
echo "STANDALONE_ETCDS_PRIVATE_DNS from second argument: ${STANDALONE_ETCDS_PRIVATE_DNS}"
echo "PBENCH_COLLECTION_INTERVAL from third argument: ${PBENCH_COLLECTION_INTERVAL}"
echo "PBENCH_RESULTS_DIR_NAME from fourth argument: ${PBENCH_RESULTS_DIR_NAME}"
echo "CLUSTER_LOADER_CONFIG_FILE from fifth argument: ${CLUSTER_LOADER_CONFIG_FILE}"
echo "WAIT_TIME_BEFORE_STOPPING_PBENCH from sixth argument: ${WAIT_TIME_BEFORE_STOPPING_PBENCH}"
echo "PBENCH_REGISTER from seventh argument:  ${PBENCH_REGISTER}"


echo -e "\nChecking current version of atomic-openshift-clients on this Test Client instance:"
yum list installed atomic-openshift-clients
yum clean all
yum list atomic-openshift-clients

### TO-DO: 
### - update the atomic-openshift-clients rpm to latest or to specified version

openshift version
oc version
echo -e "\nRemoving current /root/.kube dir on this host"
rm -rf /root/.kube

ls -ltra /root
echo -e "Creating a new /root/.kube dir on this host "
mkdir -p /root/.kube
ls -ltr /root/.kube/config

echo -e "SCP the /etc/origin/master/admin.kubeconfig file from Master node ${MASTER_PUBLIC_DNS} to this Test Client host"
scp root@${MASTER_PUBLIC_DNS}:/etc/origin/master/admin.kubeconfig /root/.kube/config
echo -e "Checking the newly copied /root/.kube/config file on this host: \n"

ls -ltr /root/.kube/config
cat /root/.kube/config

# Next step need to SCP from master the /opt/pbench-agent/config/pbench-agent.cfg, to support or test instance
# where we will run the pbench-agent.  This has config details for where to copy pbench results after test is done

echo -e "\nSCP the /opt/pbench-agent/config/pbench-agent.cfg file from Master node ${MASTER_PUBLIC_DNS} to this Test Client host"
cp /opt/pbench-agent/config/pbench-agent.cfg /opt/pbench-agent/config/pbench-agent.cfg_ORIG
scp root@${MASTER_PUBLIC_DNS}:/opt/pbench-agent/config/pbench-agent.cfg /opt/pbench-agent/config/pbench-agent.cfg
echo -e "Checking the newly copied /opt/pbench-agent/config/pbench-agent.cfg file on this host: \n"
cat /opt/pbench-agent/config/pbench-agent.cfg


echo -e "\nRunning pbench-stop-tools and pbench-clear-results on this Test Client host: \n"
pbench-stop-tools
pbench-clear-results


# get the internal node ip addresses now that we have the /root/.kube/config copied over:
## NODES are used when we want to register pbench from scratch
NODES=$(oc get nodes | grep -v "master" | grep -v NAME | awk '{print $1}'  | xargs)

ALL_NODES_INTERNAL=$(oc get nodes | grep -v NAME | awk '{print $1}'  | xargs)
MASTER_INTERNAL_IP=$(oc get nodes --no-headers -l node-role.kubernetes.io/master=true | cut -f1 -d" ")

echo -e "\nChecking node config master node:"
ssh ${MASTER_PUBLIC_DNS} "cat /etc/origin/node/node-config.yaml"

echo -e "\nNodes other than masters: ${NODES}, and etcds: ${STANDALONE_ETCDS_PRIVATE_DNS}"
echo -e "All Nodes internal ip addresses: ${ALL_NODES_INTERNAL}"
echo -e "Master internal ip address: ${MASTER_INTERNAL_IP}"

# checking if the pbench directories were created
echo -e "\nChecking if the pbench directories were previously created by Flexy"

for i in ${ALL_NODES_INTERNAL} ${STANDALONE_ETCDS_PRIVATE_DNS} ; do
  echo -e "\nssh to $i: "
  ssh $i "ls -ltr /var/lib/pbench-agent/ ; ls -ltr /var/lib/pbench-agent/tools-default"
done



echo -e "\nClearing past pbench results on all nodes:"

# Run on Test Client:
for node in ${ALL_NODES_INTERNAL} ${STANDALONE_ETCDS_PRIVATE_DNS} ; do
  echo -e "\nssh to $node: "
  ssh ${node} "pbench-clear-results"
done

sleep 10

####################################################################
# Using Flexy now with pbench_controller_count set to 1 to creates a jump node and
# runs pbench-ansible to register all nodes, so we can skip the pbench-register steps
# unless we want to over-ride this and re-register pbench
# PBENCH_REGISTER=false; # by default

if [ "${PBENCH_REGISTER}" == "true" ]; then

  echo -e "Running pbench-kill-tools pbench-clear-tools on this Test Client host: \n"
  pbench-kill-tools
  pbench-clear-tools

  echo -e "\nClearing past pbench tools setup and pbench results on all nodes:"

  # Run on Test Client:
  for node in ${ALL_NODES_INTERNAL} ${STANDALONE_ETCDS_PRIVATE_DNS} ; do
    echo -e "\nssh to $node: "
    ssh ${node} "pbench-clear-tools; pbench-clear-results"
  done

  sleep 10

  echo -e "\nSSH to test Client and register pbench on all nodes:"


  # pbench register master node first.  Handle case where we have more than one Master later, add for loop.
  echo -e "\npbench register master node first: "
  pbench-register-tool-set --interval=${PBENCH_COLLECTION_INTERVAL} --remote=${MASTER_INTERNAL_IP}
  pbench-register-tool --name=pprof --remote=${MASTER_INTERNAL_IP} -- --osecomponent=master

  # pbench register remaining nodes and/or etcd (when on separate node or nodes from master)
  echo -e "\npbench register remaining nodes and/or etcd"

  echo -e "Nodes other than masters: ${NODES} and etcds: ${STANDALONE_ETCDS_PRIVATE_DNS}"

  for i in ${NODES} ${STANDALONE_ETCDS_PRIVATE_DNS} ; do
    echo -e "\nRegistering Node:  $i : "
    pbench-register-tool-set --interval=${PBENCH_COLLECTION_INTERVAL} --remote=${i}
    pbench-register-tool --name=pprof --remote=${i} -- --osecomponent=node
  done

fi

####################################################################

# run pbench-start-tools specifying the results dir
echo -e "\nRun pbench-start-tools specifying the results dir:  ${PBENCH_RESULTS_DIR_NAME} "

pbench-start-tools --dir /var/lib/pbench-agent/${PBENCH_RESULTS_DIR_NAME}

echo -e "Sleeping for 2 minutes"
sleep 120

# checking if the pbench directories were created
for i in ${ALL_NODES_INTERNAL} ${STANDALONE_ETCDS_PRIVATE_DNS} ; do
  echo -e "\nssh to $i: "
  ssh $i "ls -ltr /var/lib/pbench-agent/${PBENCH_RESULTS_DIR_NAME}/tools-default"
done


date

echo -e "\nOCP cluster info from Master node:"
oc version
openshift version
oc get nodes -o wide
oc get nodes --show-labels
## oc get nodes -l region=primary
oc get nodes -l 'node-role.kubernetes.io/compute=true'
oc get pods --all-namespaces -o wide

docker version
docker images
docker ps
oc describe node | grep Runtime

cd /root/svt/openshift_scalability
pwd
ls -ltr

## Replace "cleanup: true" with "cleanup: false"
## in Golang Cluster-loader nodeVertical.yaml config file
## and save original config file
echo -e "\nContents of Golang Cluster loader config dir '/root/svt/openshift_scalability/config/golang/' : " 
ls -ltr /root/svt/openshift_scalability/config/golang/
echo -e "\nContents of original Node Vertical Golang Cluster loader config file:  ${CLUSTER_LOADER_CONFIG_FILE} : " 
cat /root/svt/openshift_scalability/config/golang/${CLUSTER_LOADER_CONFIG_FILE}
MY_DATE_TS=$(date +"%m-%d-%Y-%T")
echo -e "\nSaving original Node Vertical Golang Cluster loader config file:  ${CLUSTER_LOADER_CONFIG_FILE} with timestamp extension ${MY_DATE_TS}"
cp /root/svt/openshift_scalability/config/golang/${CLUSTER_LOADER_CONFIG_FILE} /root/svt/openshift_scalability/config/golang/${CLUSTER_LOADER_CONFIG_FILE}_${MY_DATE_TS}
echo -e "\nContents of Golang Cluster loader config dir '/root/svt/openshift_scalability/config/golang/' after saving a copy of file  ${CLUSTER_LOADER_CONFIG_FILE}: " 
ls -ltr /root/svt/openshift_scalability/config/golang/
echo -e "\nChanging 'cleanup: true' to 'cleanup: false' in Node Vertical config file '${CLUSTER_LOADER_CONFIG_FILE}': " 
sed -i "s/cleanup: true/cleanup: false/" /root/svt/openshift_scalability/config/golang/${CLUSTER_LOADER_CONFIG_FILE}
echo -e "Contents of modified Node Vertical Golang Cluster loader config file:  ${CLUSTER_LOADER_CONFIG_FILE} : " 
cat /root/svt/openshift_scalability/config/golang/${CLUSTER_LOADER_CONFIG_FILE}


echo -e "\n\n############## Running Golang cluster-loader ######################"
echo -e "\nCurrent bash shell options: $(echo $-)"

export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}

# For golang cluster loader config file without extension
GOLANG_CLUSTER_LOADER_CONFIG_FILE=$(echo ${CLUSTER_LOADER_CONFIG_FILE} | cut -f 1 -d '.')

echo -e "\nGoLang cluster-loader config file without extension is: '${GOLANG_CLUSTER_LOADER_CONFIG_FILE}'"
echo -e "\nRunning: '/usr/libexec/atomic-openshift/extended.test --ginkgo.focus=\"Load cluster\" --viper-config=config/golang/${GOLANG_CLUSTER_LOADER_CONFIG_FILE}"
/usr/libexec/atomic-openshift/extended.test --ginkgo.focus="Load cluster" --viper-config=config/golang/${GOLANG_CLUSTER_LOADER_CONFIG_FILE}

rc=$?

echo -e "\nFinished executing GoLang cluster-loader: exit code was: $rc"

# Restore the Node Vertical config file back to original
echo -e "\nRestoring Node Vertical Golang Cluster loader config file to:  ${CLUSTER_LOADER_CONFIG_FILE}_${MY_DATE_TS}"
ls -ltr /root/svt/openshift_scalability/config/golang/
cp /root/svt/openshift_scalability/config/golang/${CLUSTER_LOADER_CONFIG_FILE}_${MY_DATE_TS} /root/svt/openshift_scalability/config/golang/${CLUSTER_LOADER_CONFIG_FILE}
ls -ltr /root/svt/openshift_scalability/config/golang/
echo -e "\nContents of restored Node Vertical Golang Cluster loader config file ${CLUSTER_LOADER_CONFIG_FILE} :"
cat /root/svt/openshift_scalability/config/golang/${CLUSTER_LOADER_CONFIG_FILE}
DIFF_NV_CONFIG_FILES=$(diff /root/svt/openshift_scalability/config/golang/${CLUSTER_LOADER_CONFIG_FILE}_${MY_DATE_TS} /root/svt/openshift_scalability/config/golang/${CLUSTER_LOADER_CONFIG_FILE})
echo -e "\nDiff of original and restored NV config files: '${DIFF_NV_CONFIG_FILES}'"


oc get pods --all-namespaces -o wide
echo -e "\nChecking total number of running pods: $(oc get pods --all-namespaces -o wide | grep -v default | grep -ci running)"

echo -e "\nChecking total number of running pods in clusterproject0: $(oc get pods -n clusterproject0 -o wide | grep -v default | grep -ci running)"
sleep 2

echo -e "\nSleeping for ${WAIT_TIME_BEFORE_STOPPING_PBENCH} seconds ..."
sleep ${WAIT_TIME_BEFORE_STOPPING_PBENCH}

oc get projects

oc get pods --all-namespaces -o wide
echo -e "\nChecking total number of running pods: $(oc get pods --all-namespaces -o wide | grep -v default | grep -ci running)"

date
echo -e "\nStopping pbench tools ..."
pbench-stop-tools --dir /var/lib/pbench-agent/${PBENCH_RESULTS_DIR_NAME}

date
echo -e "\nPostprocessing pbench results ..."
pbench-postprocess-tools --dir /var/lib/pbench-agent/${PBENCH_RESULTS_DIR_NAME}
echo -e "\nCopying pbench results ..."
pbench-copy-results
date


# clean up
echo -e "\nDelete project clusterproject0"

oc delete project clusterproject0
echo -e "\nSleeping for 4 minutes"
sleep 240

oc get all --all-namespaces
oc get pods --all-namespaces -o wide
oc get pods --all-namespaces -o wide | grep -v default | grep -ci running

oc get projects

# Constructing URL fort pbench results URL:
echo -e "\nNode ip addresses:"
oc get nodes -o wide

echo -e "\nResults dir on pench web server: ${PBENCH_RESULTS_DIR_NAME} "
echo -e "\nAdditional info to construct URL for pbench results, Test Client instance internal ip address or instance name: "

TEST_CLIENT_UNAME=$(uname -n | cut -d'.' -f 1)
echo -e "\nTest Client instance internal uname based on internal ip address:  ${TEST_CLIENT_UNAME}"

WEBSERVER=$(cat /opt/pbench-agent/config/pbench-agent.cfg | grep "web_server =" | cut -d'=' -f 2 | cut -d' ' -f 2)
echo -e "\nExternal pbench results server: ${WEBSERVER}"

## 03-27-2018:  new pbench server for (alternate server , external:  pbench.dev.openshift.com)
## PBENCH_RESULTS_URL="http://${WEBSERVER}/pbench/results/${TEST_CLIENT_UNAME}/${PBENCH_RESULTS_DIR_NAME}/tools-default"
PBENCH_EXTERNAL_RESULTS_URL="http://${WEBSERVER}/results/${TEST_CLIENT_UNAME}/${PBENCH_RESULTS_DIR_NAME}/tools-default"
echo -e "\nExternal Pbench main results URL:   ${PBENCH_EXTERNAL_RESULTS_URL}"
PBENCH_RESULTS_URL="${PBENCH_RESULTS_INTERNAL_URL_PREFIX}/EC2::${TEST_CLIENT_UNAME}/${PBENCH_RESULTS_DIR_NAME}/tools-default"
echo -e "\nPbench main results URL:   ${PBENCH_RESULTS_URL}"

# sample sar memory URL for an application nodes:
# /EC2::ip-172-31-37-120/${PBENCH_RESULTS_DIR_NAME}/tools-default/ip-172-31-57-127.us-west-2.compute.internal/sar/memory.html"

# Find infra nodes other than master internal ip addresses:
INFRA_NODES_IPS=$(oc get nodes -l 'node-role.kubernetes.io/infra=true' | grep -v NAME | awk '{print $1}')
echo -e "\nInfra Nodes internal ip addresses: \n${INFRA_NODES_IPS}"

# Find the compute nodes
COMPUTE_NODES_IPS=$(oc get nodes -l 'node-role.kubernetes.io/compute=true' | grep -v NAME | awk '{print $1}')
echo -e "\nCompute Nodes internal ip addresses: \n${COMPUTE_NODES_IPS}"

# Find the Master Nodes
MASTER_NODES_IPS=$(oc get nodes -l 'node-role.kubernetes.io/master=true'  | grep -v NAME | awk '{print $1}') 
echo -e "\nMaster nodes internal ip addresses: \n${MASTER_NODES_IPS}"

# Find Standalone Etcd nodes
if [ "${STANDALONE_ETCDS_PRIVATE_DNS}" != "" ]; then
  echo -e "\nStandalone Etcd nodes internal ip addresses: \n${STANDALONE_ETCDS_PRIVATE_DNS}"
fi

exit


