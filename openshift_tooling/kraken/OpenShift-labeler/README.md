# Openshift-labeler

Playbook to label OpenShift nodes.

### Sample inventory
Your inventory should have groups of hosts describing the roles they play in the OpenShift cluster. This playbook looks for the following groups in the inventory file:
```
[pbench-controller]

[masters]

[nodes]

[etcd]

[lb]

[glusterfs]

[pbench-controller:vars]
label_pbench=False

```
Note: glusterfs group represents cns nodes.

### Run
```
$ ansible-playbook -i <inventory> label.yml
```
The playbook looks for kube config in Home directory and copies the config from one of the master node in case it doesn't find one.

### Labeling of nodes
The nodes are labeled as follows depending on the type of the role they play in OpenShift cluster:

- masters - node_type=master
- etcd - node_type=etcd
- nodes - node_type=node
- glusterfs - node_type=cns
- lb - node_type=lb
- infra - node_type=infra

### pbench
when using containerized pbench, we need to label all the nodes with node_type=pbench. Setting label_pbench to True will label all the nodes.
