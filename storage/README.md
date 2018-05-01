# FIO test

## Where to run

Run the playbook on any host with `ansible` installed.

So far it is tested with `ansible-2.4.2.0-1.el7.noarch`.

## Run

Change the inventory file

```
$ vi storage/inv.file
...
###The private key on the host to connect master
ansible_ssh_private_key_file="/home/hongkliu/.ssh/id_rsa_perf"
###The public key for the pod
pub_key_file_path=/home/hongkliu/repo/me/svt-secret/cert/id_rsa.pub
###The node list where the fio pod can run, usually compute nodes
client_nodes='["ip-172-31-24-40.us-west-2.compute.internal", "ip-172-31-48-250.us-west-2.compute.internal"]'

[target]
###master
ec2-34-213-109-136.us-west-2.compute.amazonaws.com
```

Run the playbook:

```sh
$ ansible-playbook -i storage/inv.file storage/fio-test.yaml
```

Only the setup tags:
```sh
$ ansible-playbook -i storage/inv.file storage/fio-test.yaml --tags setup
```

Only run the test:

```sh
$ ansible-playbook -i storage/inv.file storage/fio-test.yaml --tags run
```

Or on master

```sh
# bash -x /tmp/fio-test/files/scripts/test-storage.sh /tmp/fio-test/files
```


## TODOs

* Create multiple pods: with cluster-loader?
