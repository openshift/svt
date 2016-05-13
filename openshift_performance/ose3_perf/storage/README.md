## Document purpose
In this README document will be described Openshift performance test harness
## Requirements
Openshift storage performance test harness can be easily deployed via Jenkins as we have already Jenkins project which does that in place, but it also can be run independently of Jenkins from machine with ssh access to test machines ( ansible deployment

In order to use Jenkins approach, we created Jenkins project which is configured to run this test. Jenkins job for this purpose is
http://jenkins.example.com/view/Docker/job/ose3_io_performance_test/

Prior running jenkins job it is necessary to do below
- create new project based on  `ose3_io_performance_test`
- in beaker section of new Jenkins project, point it to proper beaker .xml file which corresponds to hardware planned to be used in test, after this follow below points to start test
- choose *Build with Parameters* build type and pick up
- storage device which will be used for docker storage backend. Yes, this device will be feed to `DEVS=/dev/` section in `/etc/sysconfig/docker-storage-setup`
- test type, at time supported are `fio` and `smallfile` tests.
- pod name, podname has to be unique and cannot have characters which are not approved by Openshift

## Usage outside of Jenkins
It is expected to have inside `/ose3_perf/storage` upstream openshift-ansible bits

`# git clone https://github.com/openshift/svt.git`

`# cd svt/openshift_performance/ose3_perf`

`# git clone https://github.com/openshift/openshift-ansible.git`

`# yum -y install ansible`

Before starting test, it is necessary to edit inventory file and adapt hostnames to machine(s) which
are going to be used for OSE
Also if is planned to use 10G interfaces, then it is necessary to add to host_vars
configuration for machine in question

## running ansible playbooks
#### Configure docker storage backed configuration file

`# ansible-playbook setup_storage.yml -i inventory_10g -f 5 --extra-vars '{"device":"sdc"}'`

In above example device `sdc` is used just as example,in your test adapt this to your needs.It is necessary to ensure that device planned to be used for docker storage backend
- has no partitions and/or filesystem signatures

If there are partitions and/or filesystem signatures present on device then
`docker-storage-setup` script which is used to set up docker storage baceked will ignore these devices and device will not be used for docker storage bacekend
To learn more about docker-storage-setup, check [docker-storage-setup-github](https://github.com/projectatomic/docker-storage-setup)
Current version of *ose3_setup.yml* delivered as part of this work,has integrated *setup_storage.yml* so will be executed automatically

## Install OSE v3 environment
`# ansible-playbook ose3_setup.yml -i inventory_10g -f 5  --extra-vars '{"interface10g":"true"}'`

## Build docker images
As docker test image *rhel-tools* is used and final test image is build from *rhel-tools* images. We use below ansible playbook to execte docker build step

` # ansible-playbook -i inventory_10g ose_setup_docker.yml --extra-vars '{"buildname":"POD_DOCKER_IMAGE_NAME"}'`



## Run tests

- fio and smallfile

`# ansible-playbook ose_run_io_test.yml -i inventory_10g -f 5 --extra-vars '{"podname":"POD_DOCKER_IMAGE_NAME","testtype":"all"}'`

- fio

`# ansible-playbook ose_run_io_test.yml -i inventory_10g -f 5 --extra-vars '{"podname":"POD_DOCKER_IMAGE_NAME","testtype":"fio"}'`

- smallfile

`# ansible-playbook ose_run_io_test.yml -i inventory_10g -f 5 --extra-vars '{"podname":"POD_DOCKER_IMAGE_NAME","testtype":"smallfile"}'`

Pod name needs to be same as docker image name and Jenkins job is already configured so that is necessary just to specify it once. In above examples it is marked as `POD_DOCKER_IMAGE_NAME` , but can be any other name which
follow OSE rules for pod naming.

##  Collecting test results
Collecting results generated during test will be done by `pbench` utility which is part of test harness. At end of test results archive will be uploaded to directory with name corresponding to pod/dockerimage name chosen in above steps ( in above examples POD_DOCKER_IMAGE_NAME ) Per current test case results will be uploaded to perf department pbench server

http://pbench.example.com/results/POD_DOCKER_IMAGE_NAME

More about pbench utility is possible to read at below github link
[pbench github](https://github.com/distributed-system-analysis/pbench)

## Open issues
- iostat and perf tools which are part of *pbench*  package sometimes prematurely ends and does not collect iostat and perf data
