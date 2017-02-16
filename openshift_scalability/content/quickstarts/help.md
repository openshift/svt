### Usage

Templates in this directory can be used with cluster loader with

```
# python cluster-loader.py -f appdeloy.yaml
```
where in `appdeloy.yaml` we can specify `storageclass` which will be used by
application pods to allocate storage

Beside `STORAGE_CLASS` parameter, we can specify also other parameters related storage
as `ACCESS_MODES` where access mode is one from https://kubernetes.io/docs/user-guide/persistent-volumes/#access-modes

`VOLUME_CAPACITY` parameter allows to specify size of volume which will be mounted
inside pod
An example of appdeploy.yaml is showed below.

Below template will

- create one project
- use templates specified by `file` line. Currently these templates are tested, it is possible to add more templates, but not tested more at this time.
-  applications starting based on specific template, will use storage class
specified with variable `STORAGE_CLASS` to allocated persistent volume claims(PVC) for applications. The storageclass must exist prior trying to use it. For instructions how to configure storage class, check OCP documentation
- `ACCESS_MODES` set to be `ReadWriteOnce`
- VOLUME_CAPACITY set to 5Gi

Mount point where PVC is mounted inside application pods is managed by applications
and we cannot add it at time as parameter.

In below template, it is possible to use different storage classes for different
applications, that means some applications can use one storage type to run while
some others different storage type. In all cases, storage class must exist before it is tried to use.

Currently it is not supported/possible to create multiple instances of same application in single project
If it is necessary to run multiple applications, then this is possible by
increasing number of projects. Future updates of these templates
will support multiple applications running in single project/namespace.

Each application template support additional parameters, if there is need to use them then check template specific parameters and specify them in section related to particular application. 

```
projects:
  - num: 1
    basename: apptest
    tuning: default
    templates:
      - num: 1
        file: ./content/quickstarts/cakephp/cakephp-mysql-pv.json
        parameters:
          - STORAGE_CLASS: "elclass"
          - ACCESS_MODES: "ReadWriteOnce"
          - VOLUME_CAPACITY: "5Gi"
      - num: 1
        file: ./content/quickstarts/django/django-postgresql-pv.json
        parameters:
          - STORAGE_CLASS: "elclass"
          - ACCESS_MODES: "ReadWriteOnce"
          - VOLUME_CAPACITY: "5Gi"
      - num: 1
        file: ./content/quickstarts/nodejs/nodejs-mongodb-pv.json
        parameters:
          - STORAGE_CLASS: "elclass"
          - ACCESS_MODES: "ReadWriteOnce"
          - VOLUME_CAPACITY: "5Gi"
      - num: 1
        file: ./content/quickstarts/dancer/dancer-mysql-pv.json
        parameters:
          - STORAGE_CLASS: "elclass"
          - ACCESS_MODES: "ReadWriteOnce"
          - VOLUME_CAPACITY: "5Gi"
      - num: 1
        file: ./content/quickstarts/daytrader/daytrader-postgresql-pv.json
        parameters:
          - STORAGE_CLASS: "elclass"
          - ACCESS_MODES: "ReadWriteOnce"
          - VOLUME_CAPACITY: "5Gi"
      - num: 1
        file: ./content/quickstarts/rails/rails-postgresql-pv.json
        parametrs:
          - STORAGE_CLASS: "elclass"
          - ACCESS_MODES: "ReadWriteOnce"
          - VOLUME_CAPACITY: "5Gi"
      - num: 1
        file: ./content/quickstarts/tomcat/tomcat8-mongodb-pv.json
        parameters:
          - STORAGE_CLASS: "elclass"
          - ACCESS_MODES: "ReadWriteOnce"
          - VOLUME_CAPACITY: "5Gi"
      - num: 1
        file: ./content/quickstarts/eap/eap64-mysql-pv.json
        parameters:
          - STORAGE_CLASS: "elclass"
          - ACCESS_MODES: "ReadWriteOnce"
          - VOLUME_CAPACITY: "5Gi"



tuningsets:
  - name: default
    pods:
      stepping:
        stepsize: 1
        pause: 0 min
      rate_limit:
        delay: 1000 ms
````
