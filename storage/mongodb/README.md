# Storage test:  Performance Benchmarking MongoDB with [YCSB](https://github.com/brianfrankcooper/YCSB) on OpenShift Container Platform (OCP)  

## Prerequisites

Prepare cluster with **pbench** to gather results

Clone **svt** repository 

```
$ git clone https://github.com/openshift/svt.git
``` 

```sh
$ cd storage/mongodb 
    $ ./mongodb.sh
```

**kubeconfig** Before start be sure `oc` client will use correct authorization:

```sh
export KUBECONFIG=/path/to/auth/kubeconfig
```
Setup project num and iteration nums in [mongodb.sh](mongodb.sh) you want to use during the test.

Setup params in [external_vars.yaml](external_vars.yaml) you want to use during the test.

If executed this way, it will pick up values specified in **external_vars.yaml** an example of **external_vars.yaml** is showed below 

```

---
test_project_name: storage-test-mongo
test_project_number: 10
delete_test_project_before_test: true
tmp_folder: /tmp/mongodb-test
MEMORY_LIMIT: 1024Mi
MONGODB_USER: redhat
MONGODB_PASSWORD: redhat
MONGODB_DATABASE: testdb
VOLUME_CAPACITY: 10Gi 
STORAGE_CLASS_NAME: glusterfs-storage
MONGODB_VERSION: 3.2
iteration: 10
ycsb_threads: 10,20
workload: workloada
recordcount: 1000       
operationcount: 1000
distribution: uniform
```

If necessary adapt **external_vars.yaml** to correspond specific test needs 

If wanting to use the latest mongo version, set the **MONGODB_VERSION** to **latest** and the mongodb.sh will find the latest version and overwrite the external_vars file.   

This example will allocate **1024Mi** RAM for MongoDB pod, run YCSB with 10,20 threads, execute **workloada** , run 10 iterations with 
**recordcount=1000** , **operationcount=1000**
Storage used for Mongodb pod will be carved from storageclass with name **gluster-storage** and size of PVC will be  **10Gi** 
YCSB **uniform** distribution will be used and 10 test projects will be created 

You can delete the **STORAGE_CLASS_NAME** from the external_vars.yaml if you want to use the default storage class; if you want to set a specific storage class you can set it in the yaml 

It is also possible to execute test with various values for memory for MongoDB pod all in one run, eg.

```

---
test_project_name: storage-test-mongo
test_project_number: 10
delete_test_project_before_test: true
tmp_folder: /tmp/mongodb-test
MEMORY_LIMIT: 512Mi,1024Mi,2048Mi,4096Mi
MONGODB_USER: redhat
MONGODB_PASSWORD: redhat
MONGODB_DATABASE: testdb
VOLUME_CAPACITY: 10Gi 
STORAGE_CLASS_NAME: glusterfs-storage
MONGODB_VERSION: 3.2
iteration: 10
ycsb_threads: 10,20,30,40
workload: workloada
recordcount: 1000       
operationcount: 1000
distribution: uniform
```

This will execute YCSB test against MongoDB pod for various combination

- run workloada,workloadb,workloadc,workloade tests with 512 MB of RAM for MongoDB and with 10,20,30,40 YCSB threads
- run workloada,workloadb,workloadc,workloade tests with 1024 MB of RAM for MongoDB pod and with 10,20,30,40 YCSB threads
- follow same matrix for other **MEMORY_LIMITS** 

**Important:** :exclamation:

If **operationcount** and **recordcount** are hit, then in order for test to work it is necessary to 
start test with bigger PVC size. 

You can run all YCSB workloads: **workloada**, **workloadb**, **workloadc**, **workloadd**, **workloade**, **workloadf**, **workload_template** but **workloadd** and **workloade** fail to run for iterations more than one in the same DB!


Final output of all project and iteration combos will be outputed to **mongodb.out**