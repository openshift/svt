# Storage test: CNS usability

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
$ ansible-playbook -i "ec2-34-215-170-11.us-west-2.compute.amazonaws.com," storage/cns_usability/cns-usability-test-restart-glusterfs-pods_1by1.yaml
```

where `ec2-34-215-170-11.us-west-2.compute.amazonaws.com` is the master node of the OCP cluster.

### Kill 2 glusterfs pods together

In this case, we expect some loss of logging entires.

```sh
$ ansible-playbook -i "ec2-34-215-170-11.us-west-2.compute.amazonaws.com," storage/cns_usability/cns-usability-test-restart-2-glusterfs-pods.yaml
```