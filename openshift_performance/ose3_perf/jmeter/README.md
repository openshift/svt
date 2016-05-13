# Benchmarking Application Latency for Apps running on OpenShift v3 using Jmeter

## Goal
- Measure the latency of applications running on OSEv3
  * Types of app
    * Static website (simple app)
    * Apps created using multiple containers, e.g. Wordpress with web and db
    container
- Create density matrix (nodes vs apps)
- Identify performance tuning parameters
- http vs https

## Sample Jenkins Job
http://jenkins.example.com/job/ose3_jmeter/

## Tools
- Jenkins
- Ansible
- [Taurus](http://gettaurus.org/]) - It is an open source test automation tool
which extends abstract the Jmeter test. We can going to use this to run Jmeter
test.
- [pbench](http://pbench.example.com/) - It is used to collect system
statistics while benchmark is running. We can also benchmark from it and collect results
as well.


## Assumption
- Only one master node in the environment
- The system used in the setup are pre-defined. Please check [sample ansible
inventory](http://example.com/git/perf-dept.git/plain/docker/openshift/jenkins/ose3_jmeter/inventory)
file for details
- Jenkins slave is configured on Taurus/Jmeter node, which would run benchmark
- By default 1GbE interface would used for doing the benchmark
   * 10 GbE interface can be used for OSE and client, look at sample Jenkins job for details
- By default result would be collected with pbench
- You can collect the stats on the colose if *pbench* option is not selected.
- Top level Jenkins workspace directory (ose3_perf) is to current folder
```
beaker        etcd    openshift-ansible  scripts        setup_dnsmasq.yml  setup_registry.yml  storage
config_files  jmeter  roles              setup_10g.yml  setup_nfs.yml      setup_router.yml
```
- Jmeter specific directory look like following
```
cleanup_slave.yml    host_vars  inventory_10g   pod_configurations  README          setup_slave_taurus.yml
create_projects.yml  inventory  ose3_setup.yml  prepare_taurus.yml  run_pbench.yml
```
- inventory and inventory_10g file should have similar content except 10G details in inventory_10g file.


## Setup
- git pull/update latest repo (From where-ever it is hosted)
  * for sample Jenkins job we use perf-dept repo
- inside the above repo, go to *ose3_jmeter* sub-directory and *git pull/update
openshift-ansible*
- With beaker re-install openshift master and nodes (**beaker_gprfc021_gprfc22.xml**)
- Setup OSE Master and Slave nodes (**ose3_setup.yml**)
  * If 10G option is selected, then setup 10G ip-adress on all nodes
  * Change hostname
  * Install git
  * Copy rhel71-ose to yum.repos.d
   * It would down the config file given as parameter while running jmeter job
  * Install/update few packages
  * yum update
- Setup DNSMASQ on master (**ose3_setup.yml - > setup_dnsmasq.yml**)
  * copy resolv.conf to resolv.conf.upstream  on all nodes
  * update resolv.conf file on all nodes to point to updated *dnsserver*
- Run the ansible job to setup OSE using  openshift-ansible repo
 (**ose3_setup.yml - > openshift-ansible/playbooks/byo/config.yml**)
- Run DNSMASQ post_installation *tag* (**ose3_setup.yml - > setup_dnsmasq.yml**)
- Setup router server on master (**ose3_setup.yml - > setup_router.yml**)
- Setup NFS server on master to have NFS backed storage for registry (**ose3_setup.yml - > setup_nfs.yml**)
- Setup Registry (**ose3_setup.yml - > setup_registry.yml**)
  * Configure it use NFS share created above
- Setup Taurus/Jmeter node (**setup_slave_taurus.yml**)
  * Install Ansible
  * Install Taurus (bzt)
  * Install pandas (not needed now)  
- Depending on input given while starting Jenkins job, create users, projects and pods (**create_projects.yml**)
  * Create user
    * Create a project per user
      * Create a pod per project
  * Update the route for each pod and capture the route for each pod in file
    * copy that URL file on Jenkins slave/jmeter system
  * we can have more number of pods in one project if needed
- Create the *Taurus* configuration file using URLS captured above on  Jenkins slave/jmeter system (prepare_taurus.yml)
- If *pbench collection* is selected then configure pbench and run *Taurus* job from it (**setup_pbench.yml**) and copy the result from Taurus to *pbench* result which get copied to central location
  *  If *pbench collection*  is not selected then run the *taurus* command and collect the result on console.
- Revert  the *resolv.conf* on Jenkins slave/jmeter system (**cleanup_slave.yml**)

## Limitations
- Multiple STI builds (quickstart template) in parallel make this system very
slow and they take time to finish.
