# EFK - Aggregate logging test harness

**Requires:** [https://github.com/openshift/openshift-ansible](openshift-ansible)

As root:
```
cd $HOME && git clone https://github.com/openshift/openshift-ansible && cd -
```


### Logging project setup

1. Clone this repository.
```
    git clone https://github.com/openshift/svt.git
```

2. Install logging with:
```
    MASTER_URL="https://ip-xxx-xx-xx-xxx.us-xxxx-x.compute.internal:8443"
    PUBLIC_MASTER_URL="https://ec2-xx-xxx-xxx-xxx.us-xxxx-x.compute.amazonaws.com:8443"
    ./enterprise-logging-setup.sh ${MASTER_URL} ${PUBLIC_MASTER_URL} 
```

3. Verify with:
``` 
    oc status
    oc get all 
    oc get pods -o wide
```

4. As sudo / root.
   Run 5 docker containers per each cluster node logging at 30kbs.
```
    export TIMES=5; ./test/manage_pods.sh -r 512
```

6. Confirm they are running with:
```
    ./test/manage_pods.sh -c 1
```

7. Define your target hosts inside the pbench_perftest.sh script and 
   start recording metrics.
   
   Example for a 600 seconds run (10 minutes).
```
    nohup ./pbench_perftest.sh -n logger_10n_5ppn_30kbs_10m -m 600
```

8. Docker kill all the containers from the cluster nodes.
```
    ./test/manage_pods.sh -k 1
```


E2E

Currently there are two ways we can execute the e2e test harness.

1. Run the script which gathers pbench metrics for a chosen test and for a given set of cluster nodes.

	Ex:

	  This will execute the E2E's with a scale option of 5, while gathering metrics with pbench.

	  ./perftest.sh -n LoggingSoak_E2E_5 -e 5

	  ./perftest.sh -h

2. Run the scripts individually from the 'test' folder. This will not gather metrics with pbench.

	Ex:
	  1) ./test/logger.sh -r 60 -l 512 -m 1

	  2) EXPORT FD=100 ; EXPORT ES=10 ; ./test/fluentd_autoscaler.sh





TODO:
 . change instructions once this lands in a rebase to just run from extended. (Tim)

Relevant Until https://github.com/kubernetes/kubernetes/pull/24536/files merges into upstream kube and openshift...

To run the e2es, you essentially follow these steps.

- git clone jayunit100/kubernetes
- cd kubernetes and checkout branch "LoggingSoak"
- hack/build-go.sh test/e2e/e2e.test

Then, we run the e2e tests, to create noisy logging pods : pods which log 1kb a second, spread out to each individual node on the cluster.

Run the e2e tests with --ginkgo.focus="Logging soak" --scale=[desired number of noisy-logging-pods per node]
so --scale=2 for example, will put 2 pods that log continuously on EVERY node in a cluster (==600 pods on a 300 node cluster, so be careful).
