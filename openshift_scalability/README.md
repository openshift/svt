# About OSE-Cluster-Loader
This package is written in python and can be used to create an environment on top of an OpenShift installation. So, basically you can create any number of projects, each having any number of following objects -- ReplicationController, Pods, Services, etc..
Note : As of now it supports only - Pods, Replicationcontrollers, Services, and Templates.

# Sample Command

```
 $ python cluster-loader.py -f pyconfig.yaml

```
Note:
* For more commandline options please use the "-h" option.
* The cluster-loader, by default, uses "oc" commands for all the requests but it has kuberbetes support as well, which can be used by supplying the "-k/--kube" flag.
* The directory "content" contains default file for all the supported object-types.
* If the "-f" option is not supplied, then the default config file is used -- pyconfig.yaml .
* For cleaning the environment, use "-d/--clean" option.

# Sample Config File
```
projects:
  - num: 2
    basename: clusterproject
    ifexists: default
    tuning: default
    templates:
      - num: 1
        file: ./content/deployment-config-1rep-template.json
        parameters:
          - IMAGE: hello-openshift
    quota: demo
    users:
      - num: 2
        role: admin
        basename: demo
        password: demo
        userpassfile: /etc/origin/openshift-passwd
    services:
      - num: 3
        file: default
        basename: testservice
    rcs:
      - num: 2
        replicas: 5
        file: default
        basename: testrc
        image: openshift/hello-openshift:v1.0.6
    pods:
      - total: 5
      - num: 40
        image: openshift/hello-openshift:v1.0.6
        basename: hellopods
        file: default
      - num: 60
        image: rhscl/python-34-rhel7:latest
        basename: pyrhelpods
        file: default
  - num: 1
    basename: testproject
 
quotas:
  - name: demo
    file: default

tuningsets:
  - name: default
    pods:
      stepping:
        stepsize: 5
        pause: 10 s
      rate_limit:
        delay: 250 ms
    templates:
      stepping:
        stepsize: 2
        pause: 10 s
      rate_limit:
        delay: 1 s

```

> Note :
> * ***ifexists*** parameter accepts values : ***reuse/delete/default***. This specifies the action to take if a namespace/project already exists. 
>  * ***reuse*** : Reuse the existing project and create all the specified objects under it.
>    * ***Note*** : in this case, provide the ***basename*** = name of project you want to reuse. So, basically per project parameter only one project can be reused.
>  * ***delete*** : Delete the existing project and proceed.
>  * ***default*** : An error will be raised saying that the project already exists.
> * ***In the "pods" section, the field - "num" stands for percentage***, i.e., the number of pods will be "num" percentage of the "total" pods
> * One more thing that you should note for the "pods" section is that the number of pods calculated are rounded down, when they are not exact integers.
>  * For example : total pods = 35, num = 30, 40, 30 . In this case the pods will be 11, 12 and 11 respectively.
>  * Note that the 11+12+11 = 34
> * The template files defined in the "templates" section must have the parameter 'IDENTIFIER'. This will be an integer that should be used in the name of the template and in the name of the resources to ensure that no naming conflicts occur.
> * The ***Tuning parameters*** have following function:
>  * ***stepping*** : This feature makes sure that after each "stepsize" pod requests are submitted, they enter the "Running" state. After all the pods in the given step are Running, then there is a delay = "pause" , before the next step.
>  * ***rate_limit*** : This makes sure that there is a delay of "rate_limit.delay" between each pod request submission.

```
This Config file will create the following objects :
  2 Projects : clusterproject0 , clusterproject1
   Each project has :
    2 users : demo0 , demo1  -- each with role as "admin"
    3 services : testservice0, testservice1, testservice2
    2 replication controllers : testrc0, testrc1   -- with 5 replicas each
    5 pods : hellopods0, hellopods1, pyrhelpods0, pyrhelpods1, pyrhelpods2
    1 quota: demo  -- see content/quota-default.json for reference
  1 Project : testproject0
   This project is empty
```
# Creating pods with persistent storage using cluster-loader 

Cluster loader supports `EBS` and `CEPH` persistant storage backeds for pods. It will be extended to support `Gluster` and `NFS` too.

`storagepyconf.yaml` is example config file. It is possible  at time using cluster-loader, only to attach one storage type to pod ( not possible
to attach ebs and ceph at same time to same pod while mounted to different mount points ) 

In order to use pods with persitant storage, it is necessary to perform step in advance and prepare Openshift master and nodes 
in order to be albe to reach storage system intended to use 

## Using cluster-loader with EBS storage backend 
[openshift documentation](https://docs.openshift.com/enterprise/3.1/install_config/configuring_aws.html) gives explanation what is necessary to do 
prior to starting pods with persitant storage residing at EBS.Please follow these steps and configure openshift master / node(s)
cluster-loader supports `region` option which will create EBSes in region specified. Per openshift documentation, `region` parameter which is configured with 
`awscli` tool. 
`aswcli configure` and answer on questions afterwards. 
cluster-loader, at time only supprots `gp2` EBS storage type. Future work will be done to support `io1` and `standard` volume types
[ec2 volume types](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSVolumeTypes.html)

EBS parameters which are requested when starting cluster-loader are 

- ebsvolumesize: X ( eg: ebsvolumesize : 1 ) - size of EBS volume in GB 
- ebsvtype: gp2 - only supported at time
- ebsregion: ec2_region 
- fstype : either xfs or ext4 

Every EBS volume will be tagged with tag specified in `ebstagprefix` field 

- ebstagprefix: ebs_amazon_my_test 

It is stronly recommended to tag EBS voluems, it is much easier to delete them later. 

After test, deleting project will delete PVC and pods associated with it. However, PVs and EBS volumes will remain. 
To delete EBS volumes after test and not leave them associated with account, one can use `delete_ebs.py` script 

`delete_ebs.py --tagname=<tag from ebstagprefix>`  - this step will be integrated in tear down process. 

##  Using cluster-loader with CEPH storage backedn 

[openshift documentation](https://docs.openshift.com/enterprise/3.1/install_config/persistent_storage/persistent_storage_ceph_rbd.html) 
gives nices overwiev of steps necessary to do in order for ceph master to be able to create pod with CEPH as persistant storage. 

cluster-storage is automation tool, and from Openshift side ceph cluster loader will create ceph images on top of already craated ceph pool
To achive this, it is necessary to get below files and put them inside `/etc/ceph/` on openshift master side
`ceph.client.admin.keyring` and `ceph.conf` 

parameters expected by cluster-loader in order to create pods with CEPH as persitant storage are 

- cephpool: cephpool_name  - ceph pool created at CEPH side
- cephimagesize: X -  the size of ceph images which will be created. One image will be mounted to one pod 
- cephmonitors: [x.x.x.x,y.y.y.y,z.z.z.z]  - list of ceph monitors. 
These are visible in `ceph.conf` at line starting with `mon_host`
- cephsecretname: ceph-secret-name - PV.json needs ceph secret name, this can be any string. Special characters not tested. 

and 

- cephsecret: <long line> 

ceph secret is used to authorise openshift side to create images. This value is different for every ceph storage,and can be 
retreived with below command if executed on OSE master ( with above ceph  files already in place in /etc/ceph ) 

`grep key /etc/ceph/ceph.client.admin.keyring  |awk '{printf "%s", $3}'|base64`

with all these parameters in place, cluster-loader will create pods using ceph as peristant storage for them. 

Above parameters are different, and depend on storage type. Some parameters are unique for all storage types 

- mountdir: /desired_location - where to mount device inside pod 
- pvpermissions:    - PV permissions 
- pvcpermissions:   - PVC permissions 

pvpermissions and pvcpermissions can be per [access modes](https://docs.openshift.com/enterprise/3.0/architecture/additional_concepts/storage.html#pv-access-modes)
some combintations of access modes will not work. Eg. having for PV `ReadWriteMany` and for PVC `ReadWriteOnce` will not work. To check is this feature of bug.

Example of config file with storage extension is `storagepyconf.yaml` 

## Todo stuff related to cluster-storage and persitant storage backends 

- implement [Error Retries and Exponential Backoff in AWS] http://docs.aws.amazon.com/general/latest/gr/api-retries.html 
for now, it will wait 10 seconds between creation of EBS volume and tagging it. 
- include Gluster and NFS 

