# EFK - Aggregate logging test harness

**Requires:** [https://github.com/openshift/openshift-ansible](openshift-ansible)

As root:
```
    $ cd $HOME && git clone https://github.com/openshift/openshift-ansible && cd -
```


### Logging project setup

Clone this repository.
```
    $ git clone https://github.com/openshift/svt.git
```



Install logging with:

```
    MASTER_URL="https://ip-xxx-xx-xx-xxx.us-xxxx-x.compute.internal:8443"
    PUBLIC_MASTER_URL="https://ec2-xx-xxx-xxx-xxx.us-xxxx-x.compute.amazonaws.com:8443"
    $ ./enterprise_logging_setup.sh ${MASTER_URL} ${PUBLIC_MASTER_URL} 

    # Alternatively use "auto" mode. 
    # This will grep MASTER_URL and PUBLIC_MASTER_URL from the master config.
    $ ./enterprise_logging_setup.sh auto 

```


Verify installation with:

``` 
    $ oc status
    $ oc get all 
    $ oc get pods -o wide -l component={es, kibana, fluentd}
```


As sudo / root.

   Run 5 docker containers, each of them logging at 30 KB/min, per cluster node.
```
   $ export TIMES=5; export MODE=1; ./test/manage_pods.sh -r 512
```


Confirm they are running with:

```
   $ export MODE=1; ./test/manage_pods.sh -c 1
```


Define your pbench --remote hosts inside a file called "pbench_nodes.lst".
Start recording metrics.
   
   Example for a 600 seconds run (10 minutes).
   Note: -m stands for Mock test.

```
    $ nohup ./pbench_perftest.sh -n logger_10n_5ppn_30KBm_10m -m 600
```

Docker kill all the containers from the cluster nodes.
```
    $ export MODE=1; ./test/manage_pods.sh -k 1
```



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


###### Phase 3 - After the run finishes.

Optimize and flush indexes.

```
    $ oc exec $es_pod -- curl -XPOST "$es_url/_refresh"

    $ oc exec $es_pod -- curl -XPOST "$es_url/_optimize?only_expunge_deletes=true&flush=true"
``` 


Like in phase 1, gets ES, OC stats, logs and disk usage for your pbench --remote nodes. 
