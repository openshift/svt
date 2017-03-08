# README for router-arp_stress.yaml configuration

[router-arp_stress.yaml](https://github.com/openshift/svt/blob/master/openshift_scalability/config/router-arp_stress.yaml) is a [cluster_loader](https://github.com/openshift/svt/tree/master/openshift_scalability) configuration which can be used to test if a cluster has issues with [incorrect ARP cache tuning for large clusters](https://docs.openshift.com/container-platform/3.4/install_config/router/default_haproxy_router.html#deploy-router-arp-cach-tuning-for-large-scale-clusters)

**Note:**  This test is very resource intensive can cause cluster failures.  It must only be used in test environments.

Example of running the test:

The environment for this test is a cluster on AWS EC2 with 1 master/etcd node, 1 router node and 6 application nodes.   All instances are m4.xlarge.

1. Clone [cluster_loader](https://github.com/openshift/svt/tree/master/openshift_scalability)
2. Edit svt/openshift_scalability/config/router-arp_stress.yaml and change the number of projects to 12
3. Run cluster_loader:  ./cluster_loader.py -f config/router-arp_stress.yaml
4. Wait for script to complete (about 30 minutes or so)

Symptoms of incorrect ARP cache tuning:
* The router pod in the default namespace goes into CrashLoopBackoff status
* hello-openshift applications become unreachable via curl command (e.g. curl hello-route-0-arp0.example.com)
* oc commands can start failing