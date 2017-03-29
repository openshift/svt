# Synthetic network tests
This test runs the uperf network benchmark (via [pbench-uperf](https://github.com/distributed-system-analysis/pbench/blob/master/agent/bench-scripts/pbench-uperf)) on N number of pod pairs. It supports running the benchmark either between pod IP addresses or service IP addresses. The test setup and the test run is defined in an ansible playbook with a python wrapper to run the playbook.

## Tests performed
The following uperf tests are run:
- TCP stream and request/response
- UDP request/response

## Assumptions
- You have copied a public ssh key for use by all nodes and pods to svt/networking/synthetic/id_rsa.pub 
- You already have a running OpenShift cluster
- If master host is not connected to pods subnet, you have a pod running to serve as ansible host, ansible_pod.
- The master_host/ansible_pod has the `oc` tool installed.
- The `oc` tool is logged in as user `system:admin`
- The ssh-able hostnames given to this script match their node name in OpenShift
- [pbench](https://github.com/distributed-system-analysis/pbench) is installed and configured on all hosts

## Requirements
Ansible version <= 1.9.4

```
# yum install ansible
$ yum install --assumeyes ansible-1.9.4-1

# pip install ansible
$ pip install ansible==1.9.4
```

## Running the test
The test is run using the network-test.py script.

### loopback

```
# podIP-to-podIP, 10 pod pairs
$ python network-test.py podIP --master <hostname> --pods 10

# svcIP-to-svcIP, 1 5 and 10 pod pairs
$ python network-test.py svcIP --master <hostname> --pods 1 5 10
```

### cross host

```
# podIP-to-podIP, master-to-node, 1 pod pair
$ python network-test.py podIP --master <master-hostname/ansible_pod-hostname> --node <node-hostname> --pods 1

# svcIP-to-svcIP, node-to-node, 6 pod pairs
$ python network-test.py svcIP --master <master-hostname/ansible_pod-hostname> --node <node1-hostname> <node2-hostname> --pods 6

# nodeIP-to-nodeIP, To run the tests between any two machines(vms or baremetals) 
$ python network-test.py nodeIP --master <machine1-ip> --node <machine2-ip>
```

### Running all the combinations
- Update config.yaml with master and nodes
- Run the tests with following 
```
$ nohup ./start-network-test.sh >> run.log & tail -f run.log
```

# STAC-N1 tests
To run STAC-N1 test harness:
```
$ python stac-test.py -o 15.0.0.10 -p 15.0.0.10 -c 15.0.0.5 -rp http://path/to/stac-n1/repo/ -f=True
```
NOTE: '-f' option represents 'fast-mode' for a quick test with lesser number of images. To run standard test, skip "-f=True".

Once completed, results can be found at the following path on the producer node:
```
/capture/n/orchestration/stats.udp-tcp-sock/
```
And a consolidated csv file at:
```
/capture/consolidatedResults.csv
```
