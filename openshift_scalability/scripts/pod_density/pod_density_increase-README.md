## pod_density_increase README

### Purpose 
The pod_density_increase.sh scripts is a tool to test the density of deployments on pods in OpenShift. This uses an underlying script (pod_density.sh). 
This specific script is used to test a slower increase in the number of pods 

This script stops if it encounters any error pods between each iteration of the run

For this script you set a base number of pods you want to create, an increment (how many new pods you want to create each time) and the max number of pods you want to create in your run



### Install [pytimeparse](https://github.com/wroberts/pytimeparse) module

```sh
$ pip install -r ../../cluster_loader_requirements.txt
```

### Setup

**Projects and applicatons:**  It is recommended that [cluster-loader](https://github.com/openshift/svt/blob/master/openshift_scalability/README.md) be used to create projects, deployments, build configurations, etc.   **pod_density** is a complimentary tool that can run the pod creation by **cluster_loader**.

An example cluster-loader config that works with build_test.py is [master-vert.yaml](https://github.com/openshift/svt/blob/master/openshift_scalability/config/master-vert-pv.yaml)

This will create namespaces as below.  These projects will be specified in the build_test json config.

```
# oc get ns
NAME                 STATUS    AGE
svt-0                Active    2h
svt-1                Active    2h
svt-2                Active    2h
...
```

### Usage 

```./pod_density.sh <yamlFile>```

Ex.) ```./pod_density.sh ../../content/pause_template.yaml```


Optional Options:

```-s or --start_num``` The number of pods/projects you want to start your pod density test at. Default is 200

```-i or --increase_counter``` Number of new pods/projects you want to increase by in each iteration. Default is 20

```-m or --max_pods``` The max amount of pods/projects you want to create. Default is 2000

Pod Density Options: 
```-sc or --scale_num``` The number of worker nodes that you want. The default is 20
 
```-cp or --cluster_processes``` Number of parallel process you want the cluster loader to run with, default is 5

```-p or --projects``` Number of projects you want to create, this will overwrite the yaml file you give as the first argument, default is 2000

