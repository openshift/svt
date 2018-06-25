#!/bin/bash 

# print usage and check number of arguments passed
if [ "$#" -lt 7 ]; then
  echo "Incorrect number of arguments $#, expecting 7:"
  echo "$0 with arguments: "
  echo "   1. MASTER_PUBLIC_DNS"
  echo "   2. STANDALONE_ETCDS_PRIVATE_DNS"
  echo "   3. PBENCH_COLLECTION_INTERVAL"
  echo "   4. PBENCH_RESULTS_DIR_NAME"
  echo "   5. CLUSTER_LOADER_CONFIG_FILE"
  echo "   6. WAIT_TIME_BEFORE_STOPPING_PBENCH"
  echo "   7. PBENCH_RESULTS_INTERNAL_URL_PREFIX"
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
PBENCH_RESULTS_INTERNAL_URL_PREFIX=$7


echo "MASTER_PUBLIC_DNS from first argument: ${MASTER_PUBLIC_DNS}"
echo "STANDALONE_ETCDS_PRIVATE_DNS from second argument: ${STANDALONE_ETCDS_PRIVATE_DNS}"
echo "PBENCH_COLLECTION_INTERVAL from third argument: ${PBENCH_COLLECTION_INTERVAL}"
echo "PBENCH_RESULTS_DIR_NAME from fourth argument: ${PBENCH_RESULTS_DIR_NAME}"
echo "CLUSTER_LOADER_CONFIG_FILE from fifth argument: ${CLUSTER_LOADER_CONFIG_FILE}"
echo "WAIT_TIME_BEFORE_STOPPING_PBENCH from sixth argument: ${WAIT_TIME_BEFORE_STOPPING_PBENCH}"
echo "PBENCH_RESULTS_INTERNAL_URL_PREFIX from seventh argument: ${PBENCH_RESULTS_INTERNAL_URL_PREFIX}"


echo -e "\nChecking current version of atomic-openshift-clients on this Test Client instance:"
yum list installed atomic-openshift-clients
yum clean all
yum list atomic-openshift-clients

openshift version
oc version

ls -ltra /root

echo -e "\nChecking the newly copied /root/.kube/config file on this host: \n"

ls -ltr /root/.kube/config
cat /root/.kube/config

echo -e "\nChecking the newly copied /opt/pbench-agent/config/pbench-agent.cfg file on this host: \n"
cat /opt/pbench-agent/config/pbench-agent.cfg


echo -e "Running pbench-stop-tools and pbench-clear-results on this Test Client or pbench-controller host: \n"
pbench-stop-tools
pbench-clear-results


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


###### Using Flexy now with pbench-controller-count set to 1, to create the pbench-ansible
###### jump node and runs pbench-register on all the nodes.

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

echo -e "\nOCP cluster info:"
oc version
openshift version
oc get nodes -o wide
oc get pods --all-namespaces -o wide

docker version
docker images
docker ps
oc describe node | grep Runtime

cd /root/svt/openshift_scalability
pwd
ls -ltr


echo -e "\n\n############## Running Golang cluster-loader ######################"
echo -e "\nCurrent bash shell options: $(echo $-)"

export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}

GOLANG_CLUSTER_LOADER_CONFIG_FILE=$(echo ${CLUSTER_LOADER_CONFIG_FILE} | cut -f 1 -d '.')

echo -e "\nGoLang cluster-loader config file without extension is: '${GOLANG_CLUSTER_LOADER_CONFIG_FILE}'"
echo -e "\nRunning: '/usr/libexec/atomic-openshift/extended.test --ginkgo.focus=\"Load cluster\" --viper-config=config/golang/${GOLANG_CLUSTER_LOADER_CONFIG_FILE}"
/usr/libexec/atomic-openshift/extended.test --ginkgo.focus="Load cluster" --viper-config=config/golang/${GOLANG_CLUSTER_LOADER_CONFIG_FILE}

rc=$?

echo -e "\nFinished executing GoLang cluster-loader: exit code was: $rc"

oc get pods --all-namespaces -o wide
echo -e "\nTotal number of running pods: $(oc get pods --all-namespaces -o wide | grep -v default | grep -ci running)"

TOTAL_CLUSTERPROJECTS=$(oc get projects | grep -c clusterproject)
echo -e "\nTotal number of clusterproject namespaces created: ${TOTAL_CLUSTERPROJECTS}"

sleep 2

for (( c=0; c<${TOTAL_CLUSTERPROJECTS}; c++ ))
do
  oc get all -n clusterproject${c}
done

echo -e "\nSleeping for 10 mins"
sleep 600

echo -e "\nDeleting the ${TOTAL_CLUSTERPROJECTS} projects we just created"
for (( c=0; c<${TOTAL_CLUSTERPROJECTS}; c++ ))
do
  oc delete project clusterproject${c}
done

oc get projects

echo -e "\nSleeping for ${WAIT_TIME_BEFORE_STOPPING_PBENCH} seconds ..."
sleep ${WAIT_TIME_BEFORE_STOPPING_PBENCH}

oc get projects

oc get pods --all-namespaces -o wide
echo -e "\nTotal number of running pods: $(oc get pods --all-namespaces -o wide | grep -v default | grep -ci running)"

date
echo -e "\nStopping pbench tools ..."
pbench-stop-tools --dir /var/lib/pbench-agent/${PBENCH_RESULTS_DIR_NAME}

date
echo -e "\nPostprocessing and copying results ..."
pbench-postprocess-tools --dir /var/lib/pbench-agent/${PBENCH_RESULTS_DIR_NAME}
pbench-copy-results
date


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

