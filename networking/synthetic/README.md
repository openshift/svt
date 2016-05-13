# Synthetic network tests
This test runs the uperf network benchmark (via [pbench-uperf](https://github.com/distributed-system-analysis/pbench/blob/master/agent/bench-scripts/pbench-uperf)) on N number of pod pairs. It supports running the benchmark either between pod IP addresses or service IP addresses. The test setup and the test run is defined in an ansible playbook with a python wrapper to run the playbook.

## Tests performed
The following uperf tests are run:
- TCP stream and request/response
- UDP request/response

## Assumptions
- You already have a running OpenShift cluster
- The master node has the `oc` tool installed
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
$ python network-test.py podIP --master <master-hostname> --node <node-hostname> --pods 1

# svcIP-to-svcIP, node-to-node, 6 pod pairs
$ python network-test.py svcIP --master <master-hostname> --node <node1-hostname> <node2-hostname> --pods 6
```

### Running all the combinations
- Update config.yaml with master and nodes
- Run the tests with following 
```
$ nohup ./start-network-test.sh >> run.log & tail -f run.log
```
