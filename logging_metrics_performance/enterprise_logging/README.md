# EFK - Aggregate logging test harness

**Requires:** [https://github.com/openshift/openshift-ansible]

As root:
```
    $ cd $HOME && git clone https://github.com/openshift/openshift-ansible && cd -
```

### Logging project setup

Clone this repository.
```
    $ git clone https://github.com/openshift/svt.git
```

Install logging by populating the deployer.conf file and by passing it to the installer:

```
    $ cat deployer.conf
    VERSION=v1.4
    CLUSTER_SIZE=3
    KIBANA_HOSTNAME=kibana.example.com
    IMAGE_PREFIX=registry.example.com/openshift
    IMAGE_VERSION=3.4.0


    $ ./enterprise_logging_setup.sh deployer.conf
```


Verify installation with:

``` 
    $ oc status
    $ oc get all 
    $ oc get pods -o wide -l component={es, kibana, fluentd}
```


### Automated testing with pbench integration

Define your pbench --remote hosts inside a file called "pbench_nodes.lst".
These will typically be all the "region=infra" pods (ElasticSearch, Kibana), plus some of the Fluentd pods.

```
    $ cat pbench_nodes.lst 
    ip-172-31-15-64.us-west-2.compute.internal
    ip-172-31-15-65.us-west-2.compute.internal   

```

Example for a 1 hour run, 25 worker pods per node, each one logging at 1KB/sec rate.

*NOTE*: pbench --interval collection rate (default 60) can be altered by passing the -i parameter.
The tools registered by default are: iostat mpstat pidstat proc-vmstat sar turbostat

```
    $ nohup ./pbench_perftest.sh -n logging_3600sec_25wppn_1024B -d 3600 -r 1024 -w 25

    (output removed)
    ...
    ...

    Saving system logs.
    Saving OpenShift logs.
    Saving ElasticSearch logs.
    Deleting ElasticSearch indices.
    Saving ElasticSearch stats.
    Collecting disk_usage_initial on ip-172-31-15-64.us-west-2.compute.internal ...

    Registering iostat mpstat pidstat proc-vmstat sar turbostat on ip-172-31-15-64.us-west-2.compute.internal
    [ip-172-31-15-64.us-west-2.compute.internal]iostat tool is now registered in group default
    [ip-172-31-15-64.us-west-2.compute.internal]mpstat tool is now registered in group default
    [ip-172-31-15-64.us-west-2.compute.internal]pidstat tool is now registered in group default
    [ip-172-31-15-64.us-west-2.compute.internal]proc-vmstat tool is now registered in group default
    [ip-172-31-15-64.us-west-2.compute.internal]sar tool is now registered in group default
    [ip-172-31-15-64.us-west-2.compute.internal]turbostat tool is now registered in group default
    Collecting disk_usage_initial on ip-172-31-15-65.us-west-2.compute.internal ...

    Registering iostat mpstat pidstat proc-vmstat sar turbostat on ip-172-31-15-65.us-west-2.compute.internal
    [ip-172-31-15-65.us-west-2.compute.internal]iostat tool is now registered in group default
    [ip-172-31-15-65.us-west-2.compute.internal]mpstat tool is now registered in group default
    [ip-172-31-15-65.us-west-2.compute.internal]pidstat tool is now registered in group default
    [ip-172-31-15-65.us-west-2.compute.internal]proc-vmstat tool is now registered in group default
    [ip-172-31-15-65.us-west-2.compute.internal]sar tool is now registered in group default
    [ip-172-31-15-65.us-west-2.compute.internal]turbostat tool is now registered in group default

    Starting Journalctl logger pods test
    Worker pod(s) per node: 25
    Load rate: 1024
    Test duration: 3600 seconds.

    Pbench --interval: 60
    ...
    ...
    (output removed)

```

The final test results will be under */var/lib/pbench-agent/*.

Example:

```
    $ ls -lrth /var/lib/pbench-agent/logging_3600s_25wppn_1024B/log
    total 0
    -rw-r--r--. 1 root root   0 Jan 22 15:54 rate-limiting.log
    drwxr-xr-x. 4 root root 104 Jan 22 15:54 du
    drwxr-xr-x. 4 root root  37 Jan 22 15:57 oc
    drwxr-xr-x. 7 root root  94 Jan 22 15:57 es
```

Execution can be terminated at any time using Ctrl-c.

```
^C
Received terminate signal. Exiting.
[*] Stopping pbench tools...
[*] Done.

Removing tmp files...
Killing running pods...

Done.
```


### Large Clusters

All cluster nodes are detected automatically and their hostnames are placed in a file called *hostlist.txt*, under the "test" directory.
Workload generator containers will be placed on every node defined inside that file.
On large clusters this file can be populated manually, as needed.


### Running test scripts manually

As sudo / root.

   Run 5 docker containers, each of them logging (journald logging driver) at 30 KB/min, per cluster node.
```
   $ ./test/manage_pods.sh -h

   $ export TIMES=5; export MODE=1; ./test/manage_pods.sh -r 512
```

Confirm they are running with:

```
   $ export MODE=1; ./test/manage_pods.sh -c 1

	ip-172-31-30-100.us-west-2.compute.internal
	f822f12ad2db        gcr.io/google_containers/busybox:1.24                                "/bin/sh -c 'while tr"   10 seconds ago      Up 8 seconds                            hopeful_kilby
	f5c83073f41c        gcr.io/google_containers/busybox:1.24                                "/bin/sh -c 'while tr"   11 seconds ago      Up 9 seconds                            adoring_payne
	eff9c15c394d        gcr.io/google_containers/busybox:1.24                                "/bin/sh -c 'while tr"   12 seconds ago      Up 10 seconds                           awesome_bhaskara
	f4bce1ce6fc4        gcr.io/google_containers/busybox:1.24                                "/bin/sh -c 'while tr"   13 seconds ago      Up 11 seconds                           furious_feynman
	aaf1d3eaabc9        gcr.io/google_containers/busybox:1.24                                "/bin/sh -c 'while tr"   14 seconds ago      Up 12 seconds                           berserk_colden

	ip-172-31-31-193.us-west-2.compute.internal
	6f00d5939a60        gcr.io/google_containers/busybox:1.24                         "/bin/sh -c 'while tr"   10 seconds ago      Up 9 seconds                            thirsty_cray
	8a059de09982        gcr.io/google_containers/busybox:1.24                         "/bin/sh -c 'while tr"   11 seconds ago      Up 10 seconds                           hungry_colden
	345494224bdd        gcr.io/google_containers/busybox:1.24                         "/bin/sh -c 'while tr"   12 seconds ago      Up 11 seconds                           condescending_curie
	4edd41f2112d        gcr.io/google_containers/busybox:1.24                         "/bin/sh -c 'while tr"   13 seconds ago      Up 12 seconds                           stupefied_hoover
	49b20c723863        gcr.io/google_containers/busybox:1.24                         "/bin/sh -c 'while tr"   14 seconds ago      Up 12 seconds                           big_einstein

	ip-172-31-31-194.us-west-2.compute.internal
	2af5148f497f        gcr.io/google_containers/busybox:1.24                               "/bin/sh -c 'while tr"   10 seconds ago      Up 8 seconds                            compassionate_northcutt
	29c30d90a1ec        gcr.io/google_containers/busybox:1.24                               "/bin/sh -c 'while tr"   11 seconds ago      Up 9 seconds                            elated_leavitt
	b69b403e2c0d        gcr.io/google_containers/busybox:1.24                               "/bin/sh -c 'while tr"   12 seconds ago      Up 10 seconds                           distracted_ptolemy
	8386df0fc3ae        gcr.io/google_containers/busybox:1.24                               "/bin/sh -c 'while tr"   13 seconds ago      Up 11 seconds                           pensive_shockley
	7dece3ad512b        gcr.io/google_containers/busybox:1.24                               "/bin/sh -c 'while tr"   14 seconds ago      Up 12 seconds                           berserk_kare

	(output removed)
	...
```

Collect pbench data while containers are logging:

Example for a 600 seconds run (10 minutes).
*NOTE*: -m stands for Mock test. Useful for quiescent runs.

```
    $ nohup ./pbench_perftest.sh -n logger_10n_5ppn_30KBm_10m -m 600
```

Docker kill all the containers from the cluster nodes.
```
    $ export MODE=1; ./test/manage_pods.sh -k 1
```


**Other logging drivers are also supported through the -d parameter.** 

[https://docs.docker.com/engine/admin/logging/overview/]

Run 2 docker containers, each of them logging (json-file logging driver) at 15 KB/min.
```
   $ export TIMES=2; export MODE=1; ./test/manage_pods.sh -r 256 -d json-file

	[+] ip-172-31-30-100.us-west-2.compute.internal
	Line length: 256
	Logging driver: json-file


	[+] ip-172-31-31-193.us-west-2.compute.internal
	Line length: 256
	Logging driver: json-file
```
The docker logs command is available only for the **json-file** and **journald** logging drivers.

## Usage recommendations

###### Run the tests for 1 hour (-m 3600) as recommended here: 

https://www.elastic.co/blog/performance-considerations-elasticsearch-indexing 
(Client side, last paragraph)

###### Journald/rsyslog rate limiting should be disabled as per sizing guidelines.

###### pbench_nodes.lst should contain all the Elasticsearch, Kibana, and at least two of the Fluentd pods hostnames.

###### Use the journald logging driver (default).



## Test description

###### Phase 1 - Before the loggers and pbench start

Delete all indexed data so that data from previous runs doesn’t add up.

```
    $ oc exec $es_pod -- curl -XDELETE "$es_url/*"
```

Gets ES node stats through the API 

```   
    $ oc exec $es_pod -- curl $es_url/_stats?pretty
```

Captures disk usage under /var/lib/origin/openshift.local.volumes/pods/


###### Phase 2 - Generate load 

Start X logger pods across N OCP cluster nodes, logging pre-defined random string at a constant 256 B/s.

Verification that data gets through: 
https://gist.github.com/rflorenc/ed5abd90292755b821c9b9a880842e89

Register pbench tools: iostat mpstat pidstat proc-vmstat sar turbostat 
Collection interval: 60 seconds


###### Phase 3 - After the run finishes.

Optimize and flush indexes.

```
    $ oc exec $es_pod -- curl -XPOST "$es_url/_refresh"

    $ oc exec $es_pod -- curl -XPOST "$es_url/_optimize?only_expunge_deletes=true&flush=true"
``` 


Like in phase 1, gets ES, OC stats, logs and disk usage for your pbench --remote nodes. 
