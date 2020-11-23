## drainNode README

### Purpose 
The drainNode.sh script is a tool to test detaching and reattaching PVC devices from/to compute nodes


### Install requirements for cluster loader

```sh
$ pip install -r ../../cluster_loader_requirements.txt
```

### Setup

**Projects and applicatons:**  It is recommended that [cluster-loader](https://github.com/openshift/svt/blob/master/openshift_scalability/README.md) be used to create projects, deployments, build configurations, etc.   **drainNode** is a complimentary tool that can run the pod creation by **cluster_loader**.

Can only have 2 **ready** worker nodes for this test case. 

The script will label the 2 worker nodes with 'aaa=bbb' and cordon one of the nodes 

**Version 3.x**
4-node cluster: 1 master, 1 infra, 2 compute node

**Version 4.x**
The nodes have to be in the same zone for the PVs to be successfully migrated. Hence when creating clusters make sure they are in the same zone.

### Usage 

```./drainNode.sh```

If you want to set the number of pods to be drained set the **pod_array** list variable 

To set the number of repitions of draining both worker nodes set **iterations** in the top of the drainNode file; Defaults to 25 iterations