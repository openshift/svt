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
Ansible version >= 2.4

```
# yum install ansible

# pip install ansible

```

## Running the test
The test is run using the network-test.py script.

	usage: network-test.py [-h] [-v OS_VERSION] [-a TCP_TESTS] [-b UDP_TESTS]
                       [-s MSG_SIZES] [-t TOTAL_SAMPLES] -m TEST_MASTER
                       [-n [TEST_NODES [TEST_NODES ...]]]
                       [-p [POD_NUMBERS [POD_NUMBERS ...]]]
                       {podIP,svcIP,nodeIP}

	positional arguments:
  			{podIP,svcIP,nodeIP}

	optional arguments:
	  -h, --help            show this help message and exit
	  -v OS_VERSION, --version OS_VERSION
	                        OpenShift version
	  -a TCP_TESTS, --tcp_tests TCP_TESTS
	                        The network test types, have to be comma seperated. Default: stream,rr 
	  -b UDP_TESTS, --udp_tests UDP_TESTS
	                        The network test types, have to be comma seperated. Default: stream,rr
	  -s MSG_SIZES, --message-sizes MSG_SIZES
	                        The sizes of messages to be used to perform the tests,
	                        have to be comma seperated. Default: 64,1024,16384
	  -t TOTAL_SAMPLES, --total-samples TOTAL_SAMPLES
	                        Number of samples to be used for the tests. Default: 3
	  -m TEST_MASTER, --master TEST_MASTER
	                        OpenShift master node
	  -n [TEST_NODES [TEST_NODES ...]], --node [TEST_NODES [TEST_NODES ...]]
	                        OpenShift node
	  -p [POD_NUMBERS [POD_NUMBERS ...]], --pods [POD_NUMBERS [POD_NUMBERS ...]]
	                        Sequence of pod numbers to test

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
OR
$ nohup ./start-network-test.sh FULL >> run.log & tail -f run.log
```

### Running the tests in CI friendly mode
- Update config.yaml with master and nodes
- Run the tests with following 
```
$ nohup ./start-network-test.sh CI >> run.log & tail -f run.log

```

# STAC-N1 tests

## Preparing Nodes
- Download [openonloader](http://www.openonload.org/) :
```
$ wget http://www.openonload.org/download/openonload-201606-u1.2.tgz
$ tar zxf openonload-201606-u1.2.tgz
```
- Install openonloader on node machines:
```
$ cd openonload-201606-u1.2/scripts
$  ./onload_install
```

## To run STAC-N1 test harness:
1. Prepare Nodes. Nodes for producer and consumer pods are decided using [OIR](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/#opaque-integer-resources-alpha-feature). cluster-admin MUST pass atleast two nodes to stac-prepare-nodes.py
```
$ python stac-prepare-nodes.py -s https://<api-server-ip>:<port> -n <node-1> <node-2> ... <node-N> -i eth0
```

2. Reboot your hosts (just once, for first time)

3. Launch producer and consumer pods. Configuration for tests MUST be hosted on a github repo and its url is passed as an argument to the script:
```
$ ./stac-build-n-deploy.sh http(s)://github.com/<username>/<stac-config-repo>.git
```
Sample stac_config file is content/stac_config.sample

4. Run the test:
```
$ ./run-stac-test.sh 
