# OpenShift "gold image" Provisioner

To reduce the time it takes to build out an OpenShift environment, and facilitate automated testing we need to bake several packages, configurations and containers into a RHEL instance.

The image provisioner will support AWS and OpenStack, and be automated with Ansible.  The following Ansible roles are run on an instance:

- provide cloud-init config
- RHEL OS setup (install latest packages, ssh keys)
- collectd-install (install and configure collectd)
- docker-config (setup storage)
- repo-install (setup custom repos)
- pbench-install (install and configure [pbench](https://github.com/distributed-system-analysis/pbench))
<<<<<<< de11837fdc93cca07ffac1c84a121ae7a3922b88
<<<<<<< d2dcb7d6b0db9d3b1303aac9a5f9d4652c5ea8f1
  - needs template for pbench-config and keys
=======
>>>>>>> initial commit of image provisioner for fast scale-out prototyping
=======
  - needs template for pbench-config and keys
>>>>>>> Update README
- aos-ansible (pull down supporting container images)
- openshift-rpm-install (install openshift RPMs, but do not configure)
