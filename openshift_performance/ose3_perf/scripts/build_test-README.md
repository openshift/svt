## build_test README

### Purpose 
The build_test.py scripts is a flexible tool for driving builds in OpenShift.  It can execute builds concurrently, sequentially, randomly or in arbitrary combinations.


### Setup

**Projects and applicatons:**  It is recommented that [cluster-loader](https://github.com/openshift/svt/blob/master/openshift_scalability/README.md) be used to create projects, deployments, build configurations, etc.   **build_test** is a complimentary tool that can run the builds created by **cluster_loader**.

**Users:**  A user which has the ability to view and run all builds in the cluster is required.  The easiest approach is to use a user with **cluster-admin** privileges.  (**TODO**:  figure out fine grained permissions required.)   In the examples here we will use a user called *redhat* with a password *redhat* which is a cluster-admin.

**build_test tool location:**   The tool can be run from the master or from a test client which is not part of the cluster.

### Usage 

python build_test.py -m [master-url] -u [user] -p [password] <optional-arguments>

Required:

- -m *master* url (e.g.  https://host.example.com:8443 or localhost:8443 if running on the master)
- -u *userid* with authority to view and execute all builds on the cluster
- -p *password* 


#### Specify builds to run each iteration:

One and only one of -a (run all builds), -f (run builds defined in json file) or -r (run random builds) must be specified

- -a run all builds defined in the cluster (default behavior - be careful if you have lots of builds defined)
- -f *file* run the builds specified in this JSON file each iteration.  See examples
- -r *number* run *number* random builds each iteration

#### Number of iterations

- -n *number* the number of iterations to repeat running the builds

#### Other parameters

- -b *batch size* number of builds to run concurrently.  Default is to run all builds requested concurrently.  See examples
- -l shuffle builds.  Builds normally run in the order returned by "oc get builds".  -l causes this list to be randomized.  Default is off.
- -s *seconds*  sleep time between iterations.  Default is 0.

### Examples

#### Run all defined builds concurrently 10 times

python build_test.py -m localhost:8443 -u redhat -p redhat -a -n 10

#### Run all defined builds 10 times - limit concurrency to 5 builds at a time

python build_test.py -m localhost:8443 -u redhat -p redhat -a -b 5 -n 10

#### Run 20 random builds concurrently 100 times

python build_test.py -m https://master.example.com:8443 -u redhat -p redhat -r 20 -n 100

#### Run the builds defined in builds.json 5 times

python build_test.py -m https://master.example.com:8443 -u redhat -p redhat -f builds.json -n 5

builds.json - JSON array of namespace and build configuration names:

```
[ 
  {"namespace":"t15", "name":"cakephp-example"},
  {"namespace":"t25", "name":"cakephp-example"},
  {"namespace":"t35", "name":"cakephp-example"},
  {"namespace":"t45", "name":"cakephp-example"},
  {"namespace":"t55", "name":"cakephp-example"}
]
```


