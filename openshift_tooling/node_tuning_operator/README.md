# Node Tuning Operator - Core functionality

## What is tested:

- Verification that after creating new resource with 'es' label pod will be tuned
- Verification that modification (increase) of a parameter: net.netfilter.nf_conntrack_max will take effect on every node of the cluster.
- Verification that modification (decrease) of a parameter: net.netfilter.nf_conntrack_max will take effect on every node of the cluster.
- Verification that modification (increase) of a parameter: kernel.pid_max will take effect on every node of the cluster.
- Verification that modification (decrease) of a parameter: kernel.pid_max will NOT take effect on every node of the cluster.
- Verification that after changing priority pod will be tuned.

## Prerequisite

OpenShift v 4.0 or higher
Python (tested with v 2.7.5)

## How to run test:

- Login to OCP
```bash
oc login -u <user_name> -p <password>
```
- Run python script with path to your ssh key
```bash
python node_tuning_operator.py /path/to/my/.ssh/libra.pem
```

- If test pass and you don't need configuration files used during test you can delete them:
```bash
rm default_values_netfilter.yaml default_values_pid.yaml default_values_priority.yaml default_values.yaml new_conntract_decrease.yaml new_conntract_increase.yaml new_kernel_pid_decrease.yaml new_kernel_pid_increase.yaml new_priority.yaml

```

## How to recover if something goes wrong:
Script has step to cleanup after test - even when test failed, but if something unexpected happen then please follow below steps:

- Delete project:
```bash
oc delete project my-logging-project
```

- Restore previous configuration:
```bash
oc delete tuned default
oc create -f ./default_values.yaml

```
