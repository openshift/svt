# Storage test: Mongodb

## Prerequisites

On the host to run the test:

```
# yum install -y ansible
```

We assume that pbench-agent has been installed and configured on the master node.

## Run the test

```sh
$ ansible-playbook -i "ec2-34-215-170-11.us-west-2.compute.amazonaws.com," storage/mongodb/mongodb-test.yaml
```

where `ec2-34-215-170-11.us-west-2.compute.amazonaws.com` is the master node of the OCP cluster.

If authentication is required against the master node, then update the following command accordingly.

```sh
$ ansible-playbook -i "ec2-34-215-170-11.us-west-2.compute.amazonaws.com," storage/mongodb/mongodb-test.yaml --extra-vars "ansible_user=root ansible_ssh_private_key_file=/home/hongkliu/.ssh/id_rsa_perf"
```

Other params in [external_vars.yaml](external_vars.yaml) can be overridden in the same way.