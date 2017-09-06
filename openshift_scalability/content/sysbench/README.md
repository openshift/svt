# Run sysbench Benchmark Test Inside OCP Pod(s)

*This document assume that all commands in below text are run on fully functional and running OCP installation with proper storage configured
 storage classes and dynamic provisioning. Refer to OCP documentation for instructions how to do configure
 storage classes and dynamic storage provisioning*

In this document it will be described what is necessary to run sysbench benchmark inside OCP pods

## Create Docker Images

It is first necessary to build *sysbench* docker images. The docker files are prepared for this for
[centos6](https://github.com/ekuric/openshift/blob/master/sysbench/dockerfiles/centos6)
and [centos7](https://github.com/ekuric/openshift/blob/master/sysbench/dockerfiles/centos7)

To build images run below commands

```
# docker build -t sysbenchcentos7 - < centos7
# docker build -t sysbenchcentos6 - < centos6
```

Ensure that these images are present on all nodes where sysbench pods are supposed to run. This can be achieved either by building them on
nodes directly, or building and pushing to registry which is used by OCP nodes and thus enable them to consume image from there.

During image build step it will get script [sysbenchose.sh](https://github.com/ekuric/openshift/blob/master/sysbench/sysbenchose.sh)
inside container and it will be used for running sysbench inside pods.

## Creating sysbench Test Pods

After successful creation of docker images, we can create sysbench pods, there are two options:

- create pods manually based on above docker image
- create pods using [clusterloader](https://github.com/openshift/svt) as described below

in next section it will be described how to create pods using *clusterloader* tool

```
$ git clone https://github.com/openshift/svt
$ cd svt/openshift_scalability
$ python cluster-loader.py -f <template_file>

```
[sysbench template_file](https://github.com/ekuric/openshift/blob/master/sysbench/sysbench-template.json) and
[sysbench parameters file](https://github.com/ekuric/openshift/blob/master/sysbench/sysbench-parameters.yaml) can be as these two files

Below is an example of *sysbench-parameters.yaml* file and that file is used as input for clusterloader

```
projects:
  - num: 1
    basename: sysbench
    tuning: default
    templates:
      - num: 1
        file: ./sysbench-template.json
        parameters:
        # oltp parameters
          - STORAGE_CLASS: "storageclass" # this is name of storage class to use
          - STORAGE_SIZE: "3Gi" # this is size of PVC mounted inside pod
          - MOUNT_PATH: "/mnt/pvcmount"
          - OLTP: "100000"

        # cpu parameters
          - CPU_PRIME: "10000"
          - MAX_REQ: "10000"

        # general parameters
          - THREADS: "1,2,4,8,16,24,48"
          - DOCKER_IMAGE: "dockerimage"
          - TESTTYPE: "cpu"
          - SYSBENCH_RESULTS: "/var/sysbench_results"

tuningsets:
  - name: default
    pods:
      stepping:
        stepsize: 5
        pause: 0 min
      rate_limit:
        delay: 0 ms

```

## Running sysbench Test in Pbench Mode

[Pbench tool](https://github.com/distributed-system-analysis/pbench) offers option to collect system data
during test execution. With system data we mean different system / performance data collected with
general tools like `sar`, `iostat`, `mpstat` and many others. For detailed list, refer to pbench [tool scripts](https://github.com/distributed-system-analysis/pbench/tree/master/agent/tool-scripts)

Pbench has `pbench-user-benchmark` [script](https://github.com/distributed-system-analysis/pbench/blob/master/agent/bench-scripts/pbench-user-benchmark)
It is possible to use `pbench-user-benchmark` script to run sysbench test and at same time to collect system data during test execution.

`pbench-user-benchmark` exports [benchmark_run_dir](https://github.com/distributed-system-analysis/pbench/blob/master/agent/bench-scripts/pbench-user-benchmark#L107)
variable and it can be used as value for `SYSBENCH_RESULTS` to ensure that sysbench data are collected to pbench directory too.

The way we then start test would be

```
# pbench-user-benchmark --config="sysbench_test" -- ./runsys.sh <projectName>.0
```

with `runsys.sh` as in this [example](https://raw.githubusercontent.com/ekuric/openshift/master/sysbench/runsys.sh)

Variable `SYSBENCH_RESULTS` for this test case would be
```
SYSBENCH_RESULTS: "$benchmark_run_dir/tools-default/sysbench_results"
```

### sysbench-parameters.yaml explanation

From above *sysbench-parameters.yaml* we want to do

- create 1 project  ( *num* )
- create 1 pod in project ( *templates-> num* )
- use template sysbench-template.json ( *file* )
- use storageclass ( *parameters->STORAGE_CLASS* ) - storage class has to be configured in advance, check
` oc get storageclass` and ensure it exists.
- storage size of 3Gi ( *parametres ->  STORAGE_SIZE* )
- mount storage inside pod to MOUNT_PATH ( *parameters -> MOUNT_PATH*) - this location
will be used for mariadb `data` and `metadata` directories
- use docker image ( *parameters-> DOCKER_IMAGE*) what docker image to use, it has to be build with
sysbench preinstalled and `sysbenchose.sh` script inside it - refer to dockerfiles for more details
- number of sysbench threads - comma separated list of numbers , eg ( *parameters -> THREADS*),
`THREADS:1,2,4,8` will run sysbench with 1,2,4,8 sysbench threads
- sysbench result location (*parameters-> SYSBENCH_RESULTS* ) this is location where
sysbench results will be saved, results will be located on host where
sysbench pod was running during sysbench pod execution
- OLTP - this is value for ` –oltp-table-size ` sysbench parameter ( *parameters -> OLTP* )
- CPU_PRIME - for sysbench CPU test, this is `prime` number to caclulate - refer to sysbench documentation
- MAX_REQ - maximum number of requests , used in sysbench CPU test type
- TESTTYPE - We have support for `CPU` and `OLTP` sysbench test types. We can run
either `CPU` (TESTTYPE: "cpu") , or `OLTP` ( TESTTYPE: "oltp", or both ( TESTTYPE:"oltpcpu" )
 during test.Pick up desired test and specifiy it in `sysbench-parameters.yaml` file

For full list of all available parameters, refer to [sysbench-template.json](https://github.com/openshift/svt/blob/master/openshift_scalability/content/sysbench/sysbench-template.json#L94-L166) file.

After setting parameters in *sysbench-parameters.yaml* running test can be started as
below

`python cluster-loader.py -f sysbench-parameters.yaml`

This will create sysbench pod and start sysbench test inside the pod. sysbench pod log example is
showed at this [link](https://gist.github.com/ekuric/5d30eb8d411b08f6b79164f38d86b1af)

In this test case, storage was originating from CNS cluster and inside sysbench pod we see below, and it is visible that
sysbench is writing to custom mount location inside sysbench pod specified with `MOUNT_PATH` in parameters file

```
# mount | grep pvcmount
10.16.153.42:vol_0634fd7e484d2620107181184178703d on /mnt/pvcmount type fuse.glusterfs (rw,relatime,user_id=0,group_id=0,default_permissions,allow_other,max_read=131072)
sh-4.2# cd /mnt/pvcmount/
sh-4.2# ls -l
total 8
drwxr-sr-x. 2 root 2000 4096 May  5 10:02 data
drwxr-sr-x. 2 root 2000 4096 May  5 10:02 datalog
```

### sysbench Test Result

Results from sysbench test will be saved on host where sysbench pod was running in
`SYSBENCH_RESULTS` location in directory which is  [$hosname -s](https://github.com/ekuric/openshift/blob/master/sysbench/sysbenchose.sh#L110) of pod where
it was executed.

For above example *sysbench-parameters.yaml* file results will be saved as showed below



```
# ls -l /var/lib/pbench-agent/pbench-user-benchmark-x.x.x/x/x/sysbench_results
# ls -l
-rw-r--r--. 1 root root 2246 May 11 07:02 sysbench_cpu_test_2017-05-11-10-49-36.txt
-rw-r--r--. 1 root root 3873 May 11 06:57 sysbench_oltp_test_2017-05-11-10-49-36.txt

```

### Running sysbench Test Using `docker run ... ` Approach

It is possible to run sysbench test directly via ` docker run .... ` approach

For this test case generic docker command would be

```
# docker run  --privileged -it -v /results_dir_location/:/results -v /test_run_location/:/home/  <image_name> /root/sysbenchose.sh -d /home -t <THREADS> -o <OLTP> -r /results
```
for example

```
# docker run  --privileged -it -v /home/results/:/results -v /home/test/:/home/  sysbenchrhel7 /root/sysbenchose.sh -d /home -t 12 -o 10000 -r /results
```

Last example will create on host in /home/results/ an directory corresponding hostname of container where
test was executed

Example output

```
# pwd
/home/results/6fa66b93bf60/threads_12
[root@gprfs013 threads_12]# ls -l
total 4
-rw-r--r--. 1 root root 1290 May  5 08:49 test_2017-05-05-12-46-51.log
[root@gprfs013 threads_12]# cat test_2017-05-05-12-46-51.log
sysbench 0.5:  multi-threaded system evaluation benchmark

Running the test with following options:
Number of threads: 12
Random number generator seed is 0 and will be ignored


Threads started!

OLTP test statistics:
    queries performed:
        read:                            1400322
        write:                           400034
        other:                           200023
        total:                           2000379
    transactions:                        100000 (4649.22 per sec.)
    read/write requests:                 1800356 (83702.55 per sec.)
    other operations:                    200023 (9299.51 per sec.)
    ignored errors:                      23     (1.07 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          21.5090s
    total number of events:              100000
    total time taken by event execution: 257.9228s
    response time:
         min:                                  1.91ms
         avg:                                  2.58ms
         max:                                 36.88ms
         approx.  95 percentile:               3.31ms

Threads fairness:
    events (avg/stddev):           8333.3333/45.64
    execution time (avg/stddev):   21.4936/0.00

```

### Quickstart for running bare metal, docker and OCP ====
```
# ./cluster-loader.py -f content/sysbench/sysbench-parameters.yaml 
# oc get pods -n sysbench0 -o wide
# ssh root@$(whatever_node_ran_sysbench) cat /var/sysbench*/sysbench*/*txt
```
```
# docker run --privileged -v /tmp:/tmp -it sysbench /root/sysbenchose.sh -t 1 -r /tmp --cpuprime 5000 --testtype cpu
```

```
# yum install https://copr-be.cloud.fedoraproject.org/results/ndokos/pbench/epel-7-x86_64/00182794-pbench-sysbench/pbench-sysbench-0.4.12-1.x86_64.rpm -y
# content/sysbench/sysbenchose.sh -t 1 -r /tmp --cpuprime 10000 --testtype cpu
```
