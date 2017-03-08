# centos-stress
CentOS based docker image.

## Prerequisites

To use the workload generator (WLG) image within the [OCP](https://www.openshift.com/container-platform/) environment, it needs to be
made retrievable from a docker registry as `svt/centos-stress` image or built on
OCP nodes hosting the WLG pods.  If you decide to use the latter method, you
need to change
[stress-pod.json](https://github.com/openshift/svt/tree/master/openshift_scalability/content/quickstarts/stress) `"imagePullPolicy"` to `"Never"`.  The WLG image `svt/centos-stress`
can be overriden by an optional
[cluster-loader](https://github.com/openshift/svt/blob/master/openshift_scalability/cluster-loader.py) parameter `WLG_IMAGE`.

OCP nodes hosting WLG pods must be labeled by a `placement=${PLACEMENT}`
label, otherwise the WLG pods will fail to fit any node.  The default value of
`${PLACEMENT}` is `test`.

Before running any of the test harnesses synchronised by the cluster-loader [autogen functionality](https://github.com/openshift/svt/blob/master/openshift_scalability/README.md) ensure you can connect from OCP nodes hosting WLG pods to a machine running cluster-loader (OCP master) to TCP port 9090.

## Test harnesses

There are several test harnesses provided by the docker image.  The recommended
way of running them is through the use of the [cluster-loader](https://github.com/openshift/svt/blob/master/openshift_scalability/cluster-loader.py) tool.  All of the test harnesses use a common template
[stress-pod.json](https://github.com/openshift/svt/blob/master/openshift_scalability/content/quickstarts/stress/stress-pod.json), but they typically use a different cluster-loader configuration file.

### stress

Add description.

### JMeter

Add description.

### wrk

This test harness makes use of a modern HTTP benchmarking tool [wrk](https://github.com/wg/wrk) with support for scripting in LUA. [stress-wrk.yaml](https://github.com/openshift/svt/blob/master/openshift_scalability/config/stress-wrk.yaml) is an example of the cluster-loader configuration file.

#### Sample run
Deploy sample applications across OCP cluster nodes.

```
# firewall-cmd --zone=public --add-port=9090/tcp --permanent && systemctl reload firewalld
$ oc label node ip-172-31-20-98.us-west-2.compute.internal placement=test
$ cd ~/svt/openshift_scalability
$ ./cluster-loader.py -vf config/master-vert.yaml # deploy some quickstart apps
$ vi config/stress-wrk.yaml # edit RUN_TIME, WRK_TARGETS, WLG_IMAGE and/or other variables as needed
$ ./cluster-loader.py -vaf config/stress-wrk.yaml
```

The results from the WLG pods will be uploaded to the host running cluster-loader to directory defined by an environment variable `benchmark_run_dir`.  If this variable is unset it defaults to `/tmp`.
