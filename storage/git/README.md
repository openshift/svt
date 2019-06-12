# git-workload test

## Before test:
* Setup pbench to collect data.
* Edit external_vars.yaml file to setup variables used in test:
  * Test project name 
  * Number of test projects
  * Do you want to delete test project before test (cleaning after previous run)
  * Volume capacity
  * Name of storage class
  * Test iteration
  
## Run test:

```
$ bash run_git.sh
```

## Check results:

* check how many pods a worker node supports and the system load (CPU, Memory, Network) on worker nodes provided by `pbench` or `grafana`.
* check the stats (overall time and the time for each of the step).
* if the storage solution is provided by containers (glusterfs or rook-ceph), check the system load on the storage nodes.
  In this case, try to avoid running the test pods on those storage node. We can achieve that by cordoning the storage nodes or using node selectors in the test pods.
