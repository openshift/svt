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
`${PLACEMENT}` in [stress-pod.json](https://github.com/openshift/svt/blob/master/openshift_scalability/content/quickstarts/stress/stress-pod.json)
is `test`.

Before running any of the test harnesses synchronised by the cluster-loader [autogen functionality](https://github.com/openshift/svt/blob/master/openshift_scalability/README.md) ensure you can connect from OCP nodes hosting WLG pods to a machine running cluster-loader (OCP master) to TCP port 9090.  This value can be changed by overriding GUN_PORT variable (see
[stress-pod.json](https://github.com/openshift/svt/blob/master/openshift_scalability/content/quickstarts/stress/stress-pod.json)).

## Test harnesses

There are several test harnesses provided by this docker image.  The recommended
way of running them is through the use of the [cluster-loader](https://github.com/openshift/svt/blob/master/openshift_scalability/cluster-loader.py) tool.  All of the test harnesses use a common template
[stress-pod.json](https://github.com/openshift/svt/blob/master/openshift_scalability/content/quickstarts/stress/stress-pod.json), but they typically use their own cluster-loader configuration file.

### stress

Add description.

### JMeter

This method of traffic generation has been deprecated.

### mb

This test harness makes use of Multiple-host HTTP(s) Benchmarking tool [mb](https://github.com/jmencak/mb).  [stress-mb.yaml](https://github.com/openshift/svt/blob/master/openshift_scalability/config/stress-mb.yaml) is an example of the cluster-loader configuration file.

#### Sample run

Allow access to cluster-loader autogen synchronisation primitive on port 9090
and label OCP nodes for WLG pods.

```
# firewall-cmd --zone=public --add-port=9090/tcp --permanent && systemctl reload firewalld
$ oc label node ip-172-31-20-98.us-west-2.compute.internal placement=test
```

Build centos-stress docker image.  Note that the step to push the image to a
docker registry is omitted here.

```
$ docker build -t svt/centos-stress ~/svt/openshift_scalability/content/centos-stress
```

Deploy sample (quickstart) applications across OCP cluster nodes.
```
$ cd ~/svt/openshift_scalability
$ ./cluster-loader.py -vf config/master-vert.yaml
```

Choose `RUN_TIME`, `MB_TARGETS` and optionally `WLG_IMAGE` and other
[stress-pod.json](https://github.com/openshift/svt/blob/master/openshift_scalability/content/quickstarts/stress/stress-pod.json) variables as needed.  Start cluster-loader in autogen mode.

```
$ vi config/stress-mb.yaml # edit RUN_TIME, MB_TARGETS, WLG_IMAGE and/or other variables as needed
$ ./cluster-loader.py -vaf config/stress-mb.yaml
```

The results from the WLG pods will be uploaded to the host running cluster-loader to directory defined by an environment variable `benchmark_run_dir`.  If this variable is unset it defaults to `/tmp`.
