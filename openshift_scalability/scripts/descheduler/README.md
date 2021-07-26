# Descheduler 


The Kube Descheduler Operator provides the ability to evict a running pod so that the pod can be rescheduled onto a more suitable node.

There are several situations where descheduling can benefit your cluster:
* Nodes are underutilized or overutilized.
* Pod and node affinity requirements, such as taints or labels, have changed and the original scheduling decisions are no longer appropriate for certain nodes.
* Node failure requires pods to be moved.
* New nodes are added to clusters.


## Installation 
1) Install latest cluster (with "ci" type)
2) Now run the command oc get route -A and get the console weburl
3) Now redirect to console using the url and login with kubeadmin & kubepassword credentials
4) Now create a namespace by clicking on "Administration" -> Namespaces-> and give the name as "openshift-kube-descheduler-operator" and click create.
5) Now click on the OperatorHub-> operators -> search for "cluster-kube-descheduler-operator"
6) click on the operator listed and make sure that the window which opens up after clicking on the operator has "provided by Red Hat, Inc."
7) click on Install & wait for the operator to get installed
8) Now run command 'oc project openshift-kube-descheduler-operator' and verify that a pod with name descheduler-operator is created
9) Now click on KubeDescheduler Tab -> create Instance
10) **Do not change the name of the instance** 
11) Set mode to **Automatic** 
12) Set the Descheduling Interval Seconds to about 300 seconds (something lower than default for testing purposes)
13) Set wanted profiles from list below


## [Profiles](https://github.com/openshift/cluster-kube-descheduler-operator#profiles)

* [AffinityAndTaints](https://github.com/openshift/cluster-kube-descheduler-operator#affinityandtaints)
* [TopologyAndDuplicates](https://github.com/openshift/cluster-kube-descheduler-operator#topologyandduplicates)
* [SoftTopologyAndDuplicates](https://github.com/openshift/cluster-kube-descheduler-operator#softtopologyandduplicates)
* [LifecycleAndUtilization](https://github.com/openshift/cluster-kube-descheduler-operator#lifecycleandutilization)
* [EvictPodsWithPVC](https://github.com/openshift/cluster-kube-descheduler-operator#evictpodswithpvc)
* [EvictPodsWithLocalStorage](https://github.com/openshift/cluster-kube-descheduler-operator#evictpodswithlocalstorage)
Along with the following profiles, which are in development and may change:
* [DevPreviewLongLifecycle](https://github.com/openshift/cluster-kube-descheduler-operator#devpreviewlonglifecycle)


## Install new Profile
1. Go to installed descheudler Operator
2. Delete instance
3. Wait for instance to be fully deleted
4. Install new instance with new profile names, make sure the name is still `cluster`
