# Storage test: CNS usability
According [gluster doc](https://docs.gluster.org/en/v3/Administrator%20Guide/arbiter-volumes-and-quorum/#replica-2-and-replica-3-volumes),

```
In a replica 3 volume, client-quorum is enabled by default and set to 'auto'.
This means 2 bricks need to be up for the write to succeed.
```

We simulate the situation of shutting down bricks by deleting the glusterfs pods.
In the 1st case, we kill glusterfs pods one by one and make sure there are always
at least 2 glusterfs pods running at any instant. During this procedure, we have
a pod with PVC backed up by the CNS that writes logs. In the end, we will verify
if the log entries is as expected without any loss.

In the 2nd case, we kill 2 glusterfs pods at the same time. As a result, loss of log
entries is expected.

## Prerequisites

On the host to run the test:

```
# yum install -y ansible
```

We assume that pbench-agent has been installed and configured on the master node.

## Run the test

### Kill glusterfs pods one by one

In this case, we expect no loss of logging entires.

```sh
$ ansible-playbook -i "<ocp_master_node>," storage/cns_usability/cns-usability-test-restart-glusterfs-pods_1by1.yaml
```

### Kill 2 glusterfs pods together

In this case, we expect some loss of logging entires.

```sh
$ ansible-playbook -i "<ocp_master_node>," storage/cns_usability/cns-usability-test-restart-2-glusterfs-pods.yaml
```