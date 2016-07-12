# OpenShift Quickstart Apps

## How to use

### Included files

For each application there are the following files:
- \<app>-\<db>.json
- \<app>-\<db>-pv.json
- \<app>-\<db>-deploy.json
- \<app>-\<db>-pv-deploy.json
- \<app>-build.json

Each application has two permutations, one with persistent volumes and one without persistent volumes. 

Within each permutation there is a complete template that includes a BuildConfig and ImageStream and a deploy only template that omits the build step. The deploy only template assumes that the container image has already been built in the `openshift` namespace. 

### cluster-loader

In the cluster-loader config directory there are corresponding cluster-loader configs for the above permutations of quickstart templates.

- master-vert.json
- master-vert-pv.json
- master-vert-deploy.json
- master-vert-pv-deploy.json

Example usage:
```
# python cluster-loader.py -f config/master-vert-pv.json
```

## Requirements and Recommendations 

### Router

To access routes from an external machine such as a server running JMeter or your workstation, dnsmasq needs to be configured on that system. 

1. Add a dnsmasq configuration file to `/etc/dnsmasq.d/` :
```
# Wildcard DNS for OpenShift Applications - Points to Router
address=/<routing-config-subdomain>/<router-host-ip-addr>
```

2. Update `/etc/resolv.conf` to point to local dnsmasq instance:
```
nameserver 127.0.0.1
<other-nameservers>
```

### Registry

- If on AWS, best to use an io1 volume instead of gp2

- Best to use a persistent volume: https://docs.openshift.com/enterprise/3.2/install_config/install/docker_registry.html#registry-production-use

### Docker Storage

- If on AWS, best to use an io1 volume for the docker storage volume on all OSE nodes instead of gp2

## About the Quickstarts

### CakePHP

Source: https://github.com/openshift/cakephp-ex

Simple landing page app with a page view counter that is written to the database. App code must be modified to [enable database example](https://github.com/openshift/cakephp-ex#enabling-the-database-example).

### Dancer

Source: https://github.com/openshift/dancer-ex

Contact list app that keeps track of names and email addresses. App code must be modified to [enable database example](https://github.com/openshift/dancer-ex#enabling-the-database-sample).

Example HTTP request to write data: 
```
# curl -XPOST -d "name=perf" -d "email=perf@redhat.com" http://dancer-mysql-example-dancer-mysql0.cloudapps.ose.com/
```

### Django

Source: https://github.com/openshift/django-ex

Simple landing page app with a page view counter that is written to the database.

### EAP

Source: https://github.com/jboss-openshift/openshift-examples

Todo app that keeps track of task summary and description. 

Example HTTP request to write data:
```
# curl -XPOST -d "summary=get+stuff+done" -d "description=omg+so+many+things" http://jws-app-tomcat8-mongodb0.cloudapps.ose.com/
```

### NodeJS

Source: https://github.com/openshift/nodejs-ex

Simple landing page app with a page view counter that is written to the database.

### Rails

Source: https://github.com/openshift/rails-ex

Blog posting app. 

TODO: figure out how to progammatically send requests, app uses cookies to validate requests. 

### Tomcat

Source: https://github.com/jboss-openshift/openshift-examples

Todo app that keeps track of task summary and description. 

Example HTTP request to write data:
```
# curl -XPOST -d "summary=get+stuff+done" -d "description=omg+so+many+things" http://jws-app-tomcat8-mongodb0.cloudapps.ose.com/
```

## Issues

### Dynamic Provisioning 

- Application templates that use persistent volumes have been modified to use dynamic provisioning

- As of OpenShift Enterprise 3.2, dynamic provisioning only works with [Cinder, Amazon EBS, and GCE volumes](https://docs.openshift.com/enterprise/3.2/install_config/persistent_storage/dynamically_provisioning_pvs.html#enabling-provisioner-plugins)

- Dynamic provisioning on Amazon EBS is [hardcoded](https://github.com/kubernetes/kubernetes/blob/master/pkg/volume/aws_ebs/aws_ebs.go#L414) to use `ext4` filesystem

### Application Templates are Copied from Upstream

- Complete templates have been modified to use dynamic provisioning for persistent volumes

- Complete templates have been edited down to create seperate build and deploy templates

- cluster-loader doesn't support creating templates from URLs, this would simplify keeping templates up-to-date by pointing to only the upstream versions

- Templates source: https://github.com/openshift/online/tree/master/templates/examples

### Forked Quickstarts

The following quickstarts need to be forked from their upstream repos to enable the database example to work:

- [cakephp](https://github.com/ofthecurerh/cakephp-ex)

- [dancer](https://github.com/ofthecurerh/dancer-ex)