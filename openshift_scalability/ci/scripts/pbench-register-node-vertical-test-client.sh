#!/bin/bash 


# print usage and check number of arguments passed
if [ "$#" -lt 6 ]; then
  echo "Incorrect number of arguments $#, expecting 6:"
  echo "$0 with arguments: "
  echo "   1. MASTER_PUBLIC_DNS"
  echo "   2. STANDALONE_ETCDS_PRIVATE_DNS"
  echo "   3. PBENCH_COLLECTION_INTERVAL"
  echo "   4. PBENCH_RESULTS_DIR_NAME"
  echo "   5. CLUSTER_LOADER_CONFIG_FILE"
  echo "   6. WAIT_TIME_BEFORE_STOPPING_PBENCH"
  exit 0
fi

echo -e "\nCurrent environment variables:\n$(env)"
echo -e "\nCurrent bash shell options: $(echo $-)"

DEFAULT_COLLECTION_DURATION_SECS=10

MASTER_PUBLIC_DNS=$1
STANDALONE_ETCDS_PRIVATE_DNS=$2
PBENCH_COLLECTION_INTERVAL=$3
PBENCH_RESULTS_DIR_NAME=$4
CLUSTER_LOADER_CONFIG_FILE=$5
WAIT_TIME_BEFORE_STOPPING_PBENCH=${6:-$DEFAULT_COLLECTION_DURATION_SECS}

echo "MASTER_PUBLIC_DNS from first argument: ${MASTER_PUBLIC_DNS}"
echo "STANDALONE_ETCDS_PRIVATE_DNS from second argument: ${STANDALONE_ETCDS_PRIVATE_DNS}"
echo "PBENCH_COLLECTION_INTERVAL from third argument: ${PBENCH_COLLECTION_INTERVAL}"
echo "PBENCH_RESULTS_DIR_NAME from fourth argument: ${PBENCH_RESULTS_DIR_NAME}"
echo "CLUSTER_LOADER_CONFIG_FILE from fifth argument: ${CLUSTER_LOADER_CONFIG_FILE}"
echo "WAIT_TIME_BEFORE_STOPPING_PBENCH from sixth argument: ${WAIT_TIME_BEFORE_STOPPING_PBENCH}"


echo -e "\nChecking current version of atomic-openshift-clients on this Test Client instance:"
yum list installed atomic-openshift-clients
yum clean all
yum list atomic-openshift-clients

oc version
echo -e "\nRemoving current /root/.kube dir on this host"
rm -rf /root/.kube

ls -ltra /root
echo -e "Creating a new /root/.kube dir on this host "
mkdir -p /root/.kube
ls -ltr /root/.kube/config

echo -e "SCP the /root/.kube/config file from Master node ${MASTER_PUBLIC_DNS} to this Test Client host"
scp root@${MASTER_PUBLIC_DNS}:/root/.kube/config /root/.kube/config
## may want to copy first: /etc/origin/master/admin.kubeconfig to /root/.kube/config
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

echo -e "Running pbench-stop-tools pbench-kill-tools pbench-clear-tools and pbench-clear-results on this Test Client host: \n"
pbench-stop-tools
pbench-kill-tools
pbench-clear-tools
pbench-clear-results


# get the internal node ip addresses now that we have the /root/.kube/config copied over:
NODES=$(oc get nodes | grep -v "SchedulingDisabled" | grep -v NAME | awk '{print $1}'  | xargs)
ALL_NODES_INTERNAL=$(oc get nodes | grep -v NAME | awk '{print $1}'  | xargs)
MASTER_INTERNAL_IP=$(oc get nodes | grep "SchedulingDisabled" | awk '{print $1}')

echo -e "\nChecking node config master node:"
ssh ${MASTER_PUBLIC_DNS} "cat /etc/origin/node/node-config.yaml"

echo -e \n"Nodes other than masters: ${NODES}, and etcds: ${STANDALONE_ETCDS_PRIVATE_DNS}"
echo -e "All Nodes internal ip addresses: ${ALL_NODES_INTERNAL}"
echo -e "Master internal ip address: ${MASTER_INTERNAL_IP}"
echo -e "\nClearing past pbench results on all nodes:"


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
oc get nodes -o wide
oc get pods --all-namespaces -o wide

docker version
docker images
docker ps

cd /root/svt/openshift_scalability
pwd
ls -ltr


echo -e "\n\n############## Running cluster-loader.py ######################"
echo -e "\nCurrent bash shell options: $(echo $-)"

echo "Path to python: $(which python)"
echo "Default python version: $(python --version)"
echo "/usr/bin/python version: $(/usr/bin/python --version)"


echo -e "\nRunning: python -u cluster-loader.py -f ${CLUSTER_LOADER_CONFIG_FILE}"

# python -u: for unbuffered stdin/out:
python -u cluster-loader.py -f ${CLUSTER_LOADER_CONFIG_FILE}

rc=$?

echo -e "\nFinished executing cluster-loader.py script, exit code was: $rc"

oc get pods --all-namespaces -o wide
echo -e "\nChecking total number of running pods: $(oc get pods --all-namespaces -o wide | grep -v default | grep -ci running)"

echo -e "\nSleeping for ${WAIT_TIME_BEFORE_STOPPING_PBENCH} seconds ..."
sleep ${WAIT_TIME_BEFORE_STOPPING_PBENCH}

oc get pods --all-namespaces -o wide
echo -e "\nChecking total number of running pods: $(oc get pods --all-namespaces -o wide | grep -v default | grep -ci running)"

date
echo -e "\nStopping pbench tools ..."
pbench-stop-tools --dir /var/lib/pbench-agent/${PBENCH_RESULTS_DIR_NAME}

date
echo -e "\nPostprocessing and copying results ..."
pbench-postprocess-tools --dir /var/lib/pbench-agent/${PBENCH_RESULTS_DIR_NAME}
pbench-copy-results
date

# When cluster-loader.py script execution above ends, we should have 250 pod son each of two application nodes, 
# and we waited 10 mins before stopping ppench

# clean up
echo -e "\nDelete project clusterproject0"

oc delete project clusterproject0
echo -e "\nSleeping for 4 minutes"
sleep 240

oc get pods --all-namespaces -o wide
oc get pods --all-namespaces -o wide | grep -v default | grep -ci running

# Constructing URL fort pbench results URL:
echo -e "\nNode ip addresses:"
oc get nodes -o wide

echo -e "\nResults dir on pench web server: ${PBENCH_RESULTS_DIR_NAME} "
echo -e "\nAdditional info to construct URL for pbench results, Test Client instance internal ip address or instance name: "

TEST_CLIENT_UNAME=$(uname -n | cut -d'.' -f 1)
echo -e "\nTest Client instance internal uname based on internal ip address:  ${TEST_CLIENT_UNAME}"

WEBSERVER=$(cat /opt/pbench-agent/config/pbench-agent.cfg | grep "web_server =" | cut -d'=' -f 2 | cut -d' ' -f 2)
echo -e "\nPbench web server: ${WEBSERVER}"

PBENCH_RESULTS_URL="http://${WEBSERVER}/pbench/results/${TEST_CLIENT_UNAME}/${PBENCH_RESULTS_DIR_NAME}/tools-default"
echo -e "\nPbench main results URL:   ${PBENCH_RESULTS_URL}"

# sample sar URL for an application nodes:
# http://perf-infra.ec2.breakage.org/pbench/results/ip-172-31-37-120/${PBENCH_RESULTS_DIR_NAME}/tools-default/ip-172-31-57-127.us-west-2.compute.internal/sar/memory.html"

# Find infra node internal ip address:
INFRA_NODE_IP_LINE=$(oc get pods -n default -o wide | grep router)
echo -e "Infra node internal ip address line:  ${INFRA_NODE_IP_LINE}"
INFRA_NODE_IP=$(echo ${INFRA_NODE_IP_LINE}|  cut -d' ' -f 7)
echo "Infra Node internal ip address:  ${INFRA_NODE_IP}"



for i in ${NODES} ; do
  if [ "${i}" = "${INFRA_NODE_IP}" ]; then
    echo -e "\nPbench main results URL for infra node:  $i : "
  else
    echo -e "\nPbench main results URL for application node:  $i : "
  fi
  echo "    ${PBENCH_RESULTS_URL}/$i"
done

if [ "${STANDALONE_ETCDS_PRIVATE_DNS}" = "" ]; then
  echo -e "\nPbench main results URL for standalone etcd node:  $i : "
  echo "    ${PBENCH_RESULTS_URL}/$i"
fi


echo -e "\nPbench main results URL for Master node:  ${PBENCH_RESULTS_URL}/${MASTER_INTERNAL_IP}"

exit


