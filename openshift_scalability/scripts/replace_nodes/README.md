## replace_nodes README

### Purpose 
The replace_node_count.py script is a test to verify that pods move over to newly created worker nodes when the nodes they were running on get deleted

### Setup

**Projects and applicatons:** 
First you need to create projects and pods within the namespaces. You can do this 2 ways, either locally or with a [jenkins job](https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/e2e-benchmarking-multibranch-pipeline/job/kube-burner/)

To run locally: 
```
git clone https://github.com/cloud-bulldozer/e2e-benchmarking
cd e2e-benchmarking/workloads/kube-burner
export WORKLOAD=cluster-density ./run.sh
```


Export all the cloud level environment variables that will help create the new machineset 
```sh
$ . ./clouds/<cloud_type>.sh
```


### Usage 

'''
```python reduce_node_count.py <cloud_type>```

Ex.) ```python reduce_node_count.py gcp```
