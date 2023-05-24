Description
------------------------------------------------------------
This automation scripts used for testing storage csi migration feature for different cloud provider

To execute run.sh, three VARIABLE can be configured

WORKLOAD_TYPE: mixed-workload, statefulset, deployment. For mixed-workload include both statefulset and deployment, mixed-workload is default value.

TOTAL_WORKLOAD: Default value is 400. Due to statefulset and deployment exercise different behavior from attach-detach controllers. For mixed-workload, 1 statefulset with 200 replicas and 200 deployments with 1 replica will be created. For statefulset, each POD(replicas) will mount one volume

WORKLOAD_CHECKING_TIMEOUT: Setting the timeout of checking pod is ready. default value: 1200s

The main entry to run scaleup workload
------------------------------------------------------------

run.sh

Usage of seperated script
------------------------------------------------------------
Deploy workload script
------------------------------------------------------------

deploy-workload.sh
 -p project name
 -t workload type: statefulset/deployment
 -n workload name
 -v pvc name
 -r default replicas

Check workload status script
------------------------------------------------------------
wait_workload_ready.sh
 -p project name
 -t workload type: statefulset/deployment
 -n workload name
 -r retry times
