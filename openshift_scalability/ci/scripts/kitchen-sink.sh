#/!/bin/bash
#set -x

function wait_for_build_completion()
{
  running=`oc get pods --all-namespaces | grep build | grep Running | wc -l`
  while [ $running -ne 0 ]; do
    sleep 5
    running=`oc get pods --all-namespaces | grep build | grep Running | wc -l`
    echo "$running builds are still running"
  done
}

function wait_for_deployment_completion()
{
  running=`oc get pods --all-namespaces | grep deploy | grep Running | wc -l`
  while [ $running -ne 0 ]; do
    sleep 5
    running=`oc get pods --all-namespaces | grep deploy | grep Running | wc -l`
    echo "$running deployments are still running"
  done

}

function check_no_error_pods()
{
  error=`oc get pods --all-namespaces | grep Error | wc -l`
  if [ $error -ne 0 ]; then
    echo "$error pods found, exiting"
    exit 1
  fi
}

cd ../../

#set iptables rule for exposing 9090 port for service by this test
iptables -A IN_public_allow -p tcp -m tcp --dport 9090 -m conntrack --ctstate NEW -j ACCEPT

#results will be copied to master, modify ssh config
echo "StrictHostKeyChecking no" >> /root/.ssh/config

oc project default

node=$(oc get nodes --show-labels | grep primary | head -1 | awk '{print $1}')

oc label node $node  placement=test

python ./cluster-loader.py -f ./ci/contents/kitchen-sink-ci.yaml

wait_for_build_completion

wait_for_deployment_completion

check_no_error_pods

python ./cluster-loader.py -af ./config/stress.yaml
