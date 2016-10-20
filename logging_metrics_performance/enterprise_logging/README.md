# EFK - Aggregate logging test harness

**Requires:** [https://github.com/openshift/openshift-ansible](openshift-ansible)

As root:
```
cd $HOME && git clone https://github.com/openshift/openshift-ansible && cd -
```


### Logging project setup

Clone this repository.
```
    git clone https://github.com/openshift/svt.git
```



Install logging with:

```
    MASTER_URL="https://ip-xxx-xx-xx-xxx.us-xxxx-x.compute.internal:8443"
    PUBLIC_MASTER_URL="https://ec2-xx-xxx-xxx-xxx.us-xxxx-x.compute.amazonaws.com:8443"
    ./enterprise_logging_setup.sh ${MASTER_URL} ${PUBLIC_MASTER_URL} 

    # Alternatively use "auto" mode. This will grep MASTER_URL and PUBLIC_MASTER_URL from the master config.
    ./enterprise_logging_setup.sh auto 

```


Verify installation with:

``` 
    oc status
    oc get all 
    oc get pods -o wide -l component={es, kibana, fluentd}
```



As sudo / root.

   Run 5 docker containers, each of them logging at 30 KB/min, per cluster node.
```
    export TIMES=5; export MODE=1; ./test/manage_pods.sh -r 512
```


Confirm they are running with:

```
    export MODE=1; ./test/manage_pods.sh -c 1
```



Define your pbench target hosts inside a file called "pbench_nodes.lst".
Start recording metrics.
   
   Example for a 600 seconds run (10 minutes).
   Note: -m stands for Mock test.

```
    nohup ./pbench_perftest.sh -n logger_10n_5ppn_30KBm_10m -m 600
```

Docker kill all the containers from the cluster nodes.
```
    export MODE=1; ./test/manage_pods.sh -k 1
```
