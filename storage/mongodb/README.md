# Storage test:  Performance Benchmarking MongoDB with [YCSB](whttps://github.com/brianfrankcooper/YCSB) on OpenShift Container Platform (OCP)  

## Prerequisites

On the host to run the test install below packages prior starting test 

```
# yum install -y ansible pbench-agent 
```

**pbench-agent** will provide pbench scripts necessary for below to run sucessfully
To read more about pbench, refer to [pbench](http://distributed-system-analysis.github.io/pbench/doc/agent/installation.html) documentation
We also assume that pbench tools 

**Below will work only if pbench is installed** 

## Run the test

Clone **svt** repository 

```
$ git clone https://github.com/openshift/svt.git
``` 



```sh
$ cd storage/mongodb 
$ ansible-playbook -i "<jump_hostname> ," storage/mongodb/mongodb-test.yaml
```

**jump_hostname** is machine with installed pbench-agent and ansible and which has complete view to OCP cluster. This can be 
machine outside of OCP cluster or OCP master machine. For case when it is machine outside of OCP master it is necessary to copy 
**/root/.kube** from master to that machine

If authentication is required against the master node, then update the following command accordingly.

```sh
$ ansible-playbook -i "<jump_hostname>," storage/mongodb/mongodb-test.yaml --extra-vars "ansible_user=root ansible_ssh_private_key_file=/path/to/key/file"
```

Other params in [external_vars.yaml](external_vars.yaml) can be overridden in the same way.

If executed this way, it will pick up what is specified in **external_vars.yaml** an example of **external_vars.yaml** is showed below 

```
---
test_project_name: storage-test-mongo
delete_test_project_before_test: true
tmp_folder: /tmp/mongodb-test
MEMORY_LIMIT: 4096Mi
MONGODB_USER: redhat
MONGODB_PASSWORD: redhat
MONGODB_DATABASE: testdb
VOLUME_CAPACITY: 150Gi 
STORAGE_CLASS_NAME: glusterfs-storage
MONGODB_VERSION: 3.2
pbench_registration: false
pbench_copy_result: false
iteration: 10
ycsb_threads: 16
workload: workloada,workloadb,workloadc,workloadd,workloade,workloadf,workload_template
recordcount: 1000       
operationcount: 1000
``` 
If necessary adapt **external_vars.yaml** to correspond specific test needs 

Also, there is small wrapper script **runmongo.sh** which enable us to specify different values of RAM for MongoDB and run all these combination in one run 

Example of usage is 
```
$ ./runmongo.sh memory_limit ycsb_threads jump_host workload iterations recordcount operationcount storageclass volumecapacity
```

For example if we execute below 

```
$ ./runmongo.sh 1024 10,20 jump_host_hostname workloada,workloadb 10 1000 1000 gluster-storage 10
``` 
This will allocate **1024Mi** RAM for MongoDB, run YCSB with 10,20 threads, execute **workloada** and **workloadb**, run 10 iterations with 
**recordcount=1000** , **operationcount=1000** using storageclass with name **gluster-storage** to allocated storage for MongoDB pod and size of PVC volume will be **10Gi** 

It is also possible to execute test with various values for memory for MongoDB pod all in one run, eg.

```
$ ./runmongo.sh 512,1024,2048,4096 10,20,30,40 jump_host_hostname workloada,workloadb,workloadc,workloade 10 1000 1000 gluster-storage 10Gi
``` 

Last command will execute YCSB test against MongoDB pod for various combination

- run workloada,workloadb,workloadc,workloade tests with 512 MB of RAM for MongoDB and with 10,20,30,40 YCSB threads
- run workloada,workloadb,workloadc,workloade tests with 1024 MB of RAM for MongoDB pod and with 10,20,30,40 YCSB threads
- follow same matrix for other **MEMORY_LIMITS** 

**Important:** If **operationcount** and **recordcount** are hight, then in order for test to work it is necessary to 
start test with bigger PVC size. 
