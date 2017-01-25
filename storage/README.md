# FIO storage tests
This test runs the fio benchmark (via [pbench-fio](https://github.com/distributed-system-analysis/pbench/blob/master/agent/bench-scripts/pbench-fio)). The test setup and the test run is defined in an ansible playbook with a python wrapper to run the playbook.

## Tests performed
The tests are run with the following options:
- Types of tests
	-read
	-write
	-read/write
	-random read
	-random write
	-random read/write
-direct=1 
-sync=1 
-block-sizes=4,64,1024 
-iodepth=2  

## Assumptions
- You have copied a public ssh key for use by all nodes and pods to svt/storage/id_rsa.pub 
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
The test is run using the storage-test.py script. Usage of the test:
	python storage-test.py fio --master <<master host name>> --node <<node host name>>
  pbench is run on the master and on the node pods are created, which use storage being tested.
The test can be invoked automatically by CI tools by updating the config.yaml with the master and nodes. And invoking the start-storage-test.sh script
 
 