# Storage test: Jenkins


## Prerequisites
On the host to run the test:

```sh
# yum install -y ansible
```

We assume that pbench-agent has been installed and configured on the master node.

## Run the test

```sh
$ ansible-playbook -i "ec2-54-186-243-252.us-west-2.compute.amazonaws.com," storage/jenkins/jenkins-test.yaml
```

where `ec2-54-186-243-252.us-west-2.compute.amazonaws.com` is the master node of the OCP cluster.

If authentication is required against the master node, then update the following command accordingly.

```sh
$ ansible-playbook -i "ec2-54-186-243-252.us-west-2.compute.amazonaws.com," storage/jenkins/jenkins-test.yaml --extra-vars "ansible_user=root ansible_ssh_private_key_file=/home/hongkliu/.ssh/id_rsa_perf"
```

Other params in external_vars.yaml can be overridden in the same way. There `jdk_username` and `jdk_password` need to be a valid login to
[oracle](http://www.oracle.com/technetwork/java/javase/downloads/index.html).