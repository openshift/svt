## Pod and Node Affinity README

### Purpose 
The pod and node affinity tests, test the ability of pods getting scheduled using Affinity and Anti-Affinity rules as we approach the capacity of compute nodes  


### Use Python2 if running using python cluster loader

The following command should return python 2
```
$ python --version 
```

If not, consider using a python 2 virtual environment.
Information can be found [here](https://docs.python-guide.org/dev/virtualenvs/) on how to install and set the virtual environment 

Activate the virutal environemnt using 
```
$ source <virtualenv_name>/bin/activate
```

Now the same command should return 2.* if done correctly 
```
$ python --version 
```

### Install Requirements 

```
$ pip install -r ../../../openshift_scalability/cluster_loader_requirements.txt
```

### Setup

**Projects and applicatons:**  It is recommended that [cluster-loader](https://github.com/openshift/svt/blob/master/openshift_scalability/README.md) be used to create projects, deployments, build configurations, etc.   **pod_density** is a complimentary tool that can run the pod creation by **cluster_loader**.

An example cluster-loader config that works with build_test.py is [master-vert.yaml](https://github.com/openshift/svt/blob/master/openshift_scalability/config/master-vert-pv.yaml)

This will create namespaces as below.  These projects will be specified in their corresponding json configs 

```
# oc get ns
NAME                 STATUS    AGE
pod-affinity-s1-0                                                 Active
pod-anti-affinity-s1-0                                            Active
s1-proj                                                           Active
```

### Usage 

```./run-node-affinity-anti-affinity.sh <golang or python>```

```./run-pod-affinity-anti-affinity.sh <golang or python>```


### Common Error Fixes

When running python 

Error: 
```AttributeError: 'str' object has no attribute 'decode'```

Fix: Make sure to use python 2 


Error: ````Error setting pause time: list index out of range````

Fix: Add a time unit to the config yaml file (pod-affinity.yaml or node-affinity.yaml) 