## build_test README

### Purpose 
The build_test.py scripts is a flexible tool for driving builds in OpenShift.  It can execute builds concurrently, sequentially, randomly or in arbitrary combinations.


### Setup

**Projects and applicatons:**  It is recommended that [cluster-loader](https://github.com/openshift/svt/blob/master/openshift_scalability/README.md) be used to create projects, deployments, build configurations, etc.   **build_test** is a complimentary tool that can run the builds created by **cluster_loader**.

An example cluster-loader config that works with build_test.py is [master-vert.yaml](https://github.com/openshift/svt/blob/master/openshift_scalability/config/master-vert-pv.yaml)

This will create namespaces as below.  These projects will be specified in the build_test json config.

```
# oc get ns
NAME                 STATUS    AGE
cakephp-mysql0       Active    2d
dancer-mysql0        Active    2d
default              Active    4d
django-postgresql0   Active    2d
eap64-mysql0         Active    2d
kube-system          Active    4d
logging              Active    4d
management-infra     Active    4d
nodejs-mongodb0      Active    2d
openshift            Active    4d
openshift-infra      Active    4d
rails-postgresql0    Active    2d
tomcat8-mongodb0     Active    2d
```

**Users:**  A user which has the ability to view and run all builds in the cluster is required.  The easiest approach is to use a user with **cluster-admin** privileges.  (**TODO**:  figure out fine grained permissions required.)   In the examples here we will use a user called *redhat* with a password *redhat* which is a cluster-admin.

In a cluster using AllowAll authentication, create the local account by logging in:

- ```oc login -u redhat -p redhat```

Then as admin, add permissions to the user ```redhat``` account:
- ```oc adm policy add-cluster-role-to-user cluster-admin redhat```

To verify that this was successful, look for the new user now has permission to read buildconfigs.

```
# oc adm policy who-can read buildconfig
Namespace: default
Verb:      read
Resource:  buildconfigs

Users:  admin
        redhat
        system:admin

Groups: system:cluster-admins
        system:masters
```


**build_test tool location:**   The tool can be run from the master or from a test client which is not part of the cluster.

### Usage 

```python build_test.py -m [master-url] -u [user] -p [password] <optional-arguments>```

Required:

- -m *master* url (e.g.  https://host.example.com:8443 or localhost:8443 if running on the master)
- -u *userid* with authority to view and execute all builds on the cluster
- -p *password* 


#### Specify builds to run each iteration:

One and only one of -a (run all builds), -f (run builds defined in json file) or -r (run random builds) must be specified.

- -a run all builds defined in the cluster (default behavior - be careful if you have lots of builds defined)
- -f *file* run the builds specified in this JSON file each iteration.  See examples
- -r *number* run *number* random builds each iteration
- -w *number* start *number* threads to do builds

#### Number of iterations

- -n *number* the number of iterations through json file

#### Other parameters

- -b *batch size* number of builds to run concurrently.  Default is to run all builds requested concurrently.  See examples
- -l shuffle builds.  Builds normally run in the order returned by "oc get builds".  -l causes this list to be randomized.  Default is off.
- -s *seconds*  sleep time between iterations.  Default is 0.

### Examples

#### Run all defined builds concurrently 10 times

```python build_test.py -m localhost:8443 -u redhat -p redhat -a -n 10```

#### Run all defined builds 10 times - limit concurrency to 5 builds at a time

```python build_test.py -m localhost:8443 -u redhat -p redhat -a -b 5 -n 10```

#### Run 20 random builds concurrently 100 times

```python build_test.py -m https://master.example.com:8443 -u redhat -p redhat -r 20 -n 100```

#### Run the builds defined in builds.json 5 times

```python build_test.py -m https://master.example.com:8443 -u redhat -p redhat -f builds.json -n 5```

builds.json - JSON array of namespace and build configuration names:

```
# cat builds_example.json
[
  {"namespace":"cakephp-mysql0", "name":"cakephp-mysql-example"},
  {"namespace":"dancer-mysql0", "name":"dancer-mysql-example"},
  {"namespace":"django-postgresql0", "name":"django-psql-example"},
  {"namespace":"eap64-mysql0", "name":"eap-app"},
  {"namespace":"nodejs-mongodb0", "name":"nodejs-mongodb-example"},
  {"namespace":"rails-postgresql0", "name":"rails-postgresql-example"},
  {"namespace":"tomcat8-mongodb0", "name":"jws-app"}
]
```

### Run output

```
# python build_test.py -m localhost:8443 -u redhat -p redhat -a -n 3 -f test.json
Gathering build info...
Build info gathered.
2017-02-06 08:37:17: iteration: 1
All threads started, starting builds and joining

Build is: dancer-mysql0:dancer-mysql-example-2

Build is: django-postgresql0:django-psql-example-2

Build is: rails-postgresql0:rails-postgresql-example-2

Build is: cakephp-mysql0:cakephp-mysql-example-2

Build is: eap64-mysql0:eap-app-2

Build is: tomcat8-mongodb0:jws-app-2

Build is: nodejs-mongodb0:nodejs-mongodb-example-2

Build completed: nodejs-mongodb0:nodejs-mongodb-example-2 Build time: 37.0 Push time: 6.0

Build completed: cakephp-mysql0:cakephp-mysql-example-2 Build time: 39.0 Push time: 4.0

Build completed: tomcat8-mongodb0:jws-app-2 Build time: 122.0 Push time: 33.0

Build completed: django-postgresql0:django-psql-example-2 Build time: 131.0 Push time: 9.0

Build completed: rails-postgresql0:rails-postgresql-example-2 Build time: 208.0 Push time: 11.0

Build completed: eap64-mysql0:eap-app-2 Build time: 215.0 Push time: 67.0

Build completed: dancer-mysql0:dancer-mysql-example-2 Build time: 292.0 Push time: 12.0
All threads joined.  Sleeping 0 before next iteration

<snip>

Build: cakephp-mysql0:cakephp-mysql-example
        Total builds: 3 Failures: 0
        Avg build time: 34.6666666667 Max build time: 39.0 Min build time: 29.0
        Avg push time: 5.33333333333 Max push time: 6.0 Min push time: 4.0

Build: dancer-mysql0:dancer-mysql-example
        Total builds: 3 Failures: 0
        Avg build time: 244.333333333 Max build time: 292.0 Min build time: 212.0
        Avg push time: 13.3333333333 Max push time: 15.0 Min push time: 12.0

Build: django-postgresql0:django-psql-example
        Total builds: 3 Failures: 0
        Avg build time: 110.666666667 Max build time: 131.0 Min build time: 99.0
        Avg push time: 11.0 Max push time: 16.0 Min push time: 8.0

Build: eap64-mysql0:eap-app
        Total builds: 3 Failures: 0
        Avg build time: 143.666666667 Max build time: 215.0 Min build time: 66.0
        Avg push time: 24.6666666667 Max push time: 67.0 Min push time: 3.0

Build: nodejs-mongodb0:nodejs-mongodb-example
        Total builds: 3 Failures: 0
        Avg build time: 50.0 Max build time: 61.0 Min build time: 37.0
        Avg push time: 16.3333333333 Max push time: 30.0 Min push time: 6.0

Build: rails-postgresql0:rails-postgresql-example
        Total builds: 3 Failures: 0
        Avg build time: 177.333333333 Max build time: 208.0 Min build time: 151.0
        Avg push time: 11.3333333333 Max push time: 14.0 Min push time: 9.0

Build: tomcat8-mongodb0:jws-app
        Total builds: 3 Failures: 0
        Avg build time: 76.6666666667 Max build time: 122.0 Min build time: 53.0
        Avg push time: 14.6666666667 Max push time: 33.0 Min push time: 4.0

Failed builds: 0
Invalid builds: 0
Good builds included in stats: 21

Average build time, all good builds: 119.619047619
Minimum build time, all good builds: 29.0
Maximum build time, all good builds: 292.0

Average push time, all good builds: 13.8095238095
Minimum push time, all good builds: 3.0
Maximum push time, all good builds: 67.0
```
