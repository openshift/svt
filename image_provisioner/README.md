# OpenShift "gold image" Provisioner

To reduce the time it takes to build out an OpenShift environment, and facilitate automated testing we need to bake several packages, configurations and containers into a RHEL instance.

The image provisioner will support AWS and OpenStack, and be automated with Ansible.  The following Ansible roles are run on an instance:

- provide cloud-init config
- RHEL OS setup (install latest packages, ssh keys)
- collectd-install (install and configure collectd)
- docker-config (setup storage)
- repo-install (setup custom repos)
- pbench-install (install and configure [pbench](https://github.com/distributed-system-analysis/pbench))
  - needs template for pbench-config and keys
- aos-ansible (pull down supporting container images)
- openshift-rpm-install (install openshift RPMs, but do not configure)
