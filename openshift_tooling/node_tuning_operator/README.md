# Node Tuning Operator - Core functionality

## What is tested:

- Verification that after creating new resource with 'es' label pod will be tuned
- Verification that modification (increase) of a parameter: net.netfilter.nf_conntrack_max will take effect on every node of the cluster.
- Verification that modification (decrease) of a parameter: net.netfilter.nf_conntrack_max will take effect on every node of the cluster.
- Verification that modification (increase) of a parameter: kernel.pid_max will take effect on every node of the cluster.
- Verification that modification (decrease) of a parameter: kernel.pid_max will NOT take effect on every node of the cluster.
- Verification that after changing priority pod will be tuned.

## How to run test:

- Export path to KUBECONFIG
```bash
export KUBECONFIG=/path/to/kubeconfig
```
- Login to OCP
```bash
oc login -u <user_name> -p <password>
```
- Run script with path to your ssh key
```bash
python node_tuning_operator.py /path/to/my/.ssh/libra.pem
```
