# openshift-labeler
Tool to label openshift nodes based on the node_role they play in openshift cluster and generate a tooling inventory on fly by looking at the node labels.

### Requirements
- Ansible
- OpenShift inventory

### Run
```
$ cd openshift-labeler
$ ansible-playbook -vv -i <openshift-inventory> openshift_label.yml
```

### Labeling of openshift nodes
The nodes in the openshift cluster are labeled as follows:

- master                         - node-role.kubernetes.io/master=true 
- nodes                          - node-role.kubernetes.io/compute=true
- etcd                           - node-role.kubernetes.io/master=true
- infra                          - node-role.kubernetes.io/infra=true
- lb                             - node-role.kubernetes.io/lb=true
- glusterfs                      - node-role.kubernetes.io/cns=true

### Sample Inventory generated
```
[pbench-controller]
foo.controller.com

[masters]
foo.master.com

[nodes]
foo.node.com

[etcd]
foo.master.com

[infra]
foo.infra.com

[lb]
foo.lb.com

[glusterfs]
foo.cns.com

[prometheus-metrics]
foo.master.com port=8443 cert=/etc/origin/master/admin.crt key=/etc/origin/master/admin.key
foo.master.com port=10250 cert=/etc/origin/master/admin.crt key=/etc/origin/master/admin.key
foo.node.com port=10250 cert=/etc/origin/master/admin.crt key=/etc/origin/master/admin.key
foo.node.com port=10250 cert=/etc/origin/master/admin.crt key=/etc/origin/master/admin.key

[pbench-controller:vars]
register_all_nodes=False
```

## Location of the inventory
By default it genrates the inventory at /root/tooling_inventory, tooling_inv variable can be set to a different path to change the location.
