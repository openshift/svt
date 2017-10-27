# Running STAC-A2 benchmark on Kubernetes 1.8

This repository contains examples for running the accelerator-friendly STAC-A2 benchmark on Kubernetes 1.8.  The benchmark itself is available to licensees through the benchmark consortia only.  This repository contains no actual benchmark code.

For more information about this benchmark:  https://stacresearch.com/a2

#### There are many fixups and optimizations in our backlog to clean up and automate.

##

### Assumptions
* STAC-A2 is installed on bare metal
* The NVIDIA driver, nvidia-docker2 and nvidia-container-runtime are installed on bare metal
* The STAC-A2 harness directory will be bind-mounted into the container at runtime.

### Software Versions used
* Red Hat Enterprise Linux 7.4
* Kubernetes 1.8 started with ```hack/local-up-cluster.sh```
* docker-1.12.6
* etcd-3.2.7

### Step 1:  Build container images
This assumes that your base system is properly registered with Red Hat (i.e. subscription-manager) or otherwise has access to the proper set of yum repos.

The rhel7-cuda9 image will be cleaned up to eventually be the parent image of the others.

```
cd rhel7-cuda9
docker build -t rhel7-cuda9 .
```

The rhel7-cuda9-nvidia-device-plugin container image implements the [Kubernetes Device Plugin]( https://github.com/kubernetes/community/blob/master/contributors/design-proposals/resource-management/device-plugin.md), which allows pods to request GPUs by updating the node capacity with the quantity of GPUs that exist on the node.

```
cd rhel7-cuda9-nvidia-device-plugin
docker build -t rhel7-cuda9-nvidia-device-plugin .
```

The rhel7-cuda9-stac-a2 container includes all the necessary CUDA libraries, R libraries and support packages required by the STAC-A2 harness.

```
cd rhel7-cuda9-stac-a2
docker build -t rhel7-cuda9-stac-a2 .
```

### Step 2:  Start the device-plugin daemonset

The device-plugin is implemented as a [Daemonset](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/).  A daemonset will launch a pod on every node in the environment.  Only nodes with NVIDIA drivers and hardware installed will have their capacity updated.  The Kubernetes scheduler uses labels and then the Kubelet uses node capacity to route workload pods to servers that have available GPUs and then subsequently allocate N-GPUs to that pod.

```kubectl create -f rhel7-cuda9-nvidia-device-plugin/nvidia-device-plugin.yml```

You can see this update with
``` kubectl describe node x.y.z```

### Step 3:  Create a pod that uses the daemonset 

#### Create the STAC-A2 pod (aka container)
```# kubectl create -f stac-pod.yml```

After a few seconds, this will show the stac-a2 pod in Running state)
```# kubectl get pods```

### Step 4: Run the workload
#### Tune the GPUs to their maximum clock frequency:
```
# nvidia-sudo nvidia-smi -pm ENABLED
# nvidia-smi --applications-clocks=877,1380
```
### Get a terminal within the GPU pod:
```# kubectl exec -it stac-a2```

You are now inside a container running in Kubernetes.  This pod is specially created to pass-through all GPUs.  Use ```lspci``` within the pod to confirm.

### Execute the harness as normal, i.e.
```# ./run_all.sh```

### Notes
* The pre-audit run took 151 minutes to complete in Kubernetes.
* The output of the benchmark is written to the host filesystem so you can exit the pod and the results zip file will persist on the host machine.
