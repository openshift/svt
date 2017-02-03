#/!/bin/bash
#set -x
################################################
## Auth=vlaad@redhat.com
## Desription: Script for running concurrent 
## build tests.
################################################
master=$1
build_array=(1 5 10 20 40)

function delete_projects()
{
  echo "deleting projects"
  oc delete project -l purpose=test
}

function create_cakephp_projects()
{
  #create cakephp projects
  echo "creating cakephp projects"
  python ../../../openshift_scalability/cluster-loader.py -f ../content/conc_builds_cakephp.yaml
}

function create_eap_projects()
{
  #create eap projects
  echo "creating eap projects"
  python ../../../openshift_scalability/cluster-loader.py -f ../content/conc_builds_eap.yaml
}

function run_builds()
{
  for i in "${build_array[@]}"
  do
    echo "starting $i concurrent builds"
    python ../../ose3_perf/scripts/build_test.py -u redhat -p redhat -m $master -n 3 -r $i >> conc_builds.out
    sleep 30
  done
}

function wait_for_build_completion()
{
  running=`oc get pods --all-namespaces | grep proj | grep build | grep Running | wc -l`
  while [ $running -ne 0 ]; do
    sleep 5
    running=`oc get pods --all-namespaces | grep proj | grep build | grep Running | wc -l`
    echo "$running builds are still running"
  done
}

function wait_for_project_termination()
{
  terminating=`oc get projects | grep Terminating | wc -l`
  while [ $terminating -ne 0 ]; do
    sleep 5
    running=`oc get projects | grep Terminating | wc -l`
    echo "$terminating projects are still terminating"
  done
}

#setup user for build tests
oc login -u system:admin
htpasswd -b /etc/origin/htpasswd redhat redhat
oadm policy add-cluster-role-to-user admin redhat

echo "Starting cakephp builds" >> conc_builds.out
create_cakephp_projects
wait_for_build_completion
run_builds
delete_projects
wait_for_project_termination
echo "Finished cakephp builds" >> conc_builds.out

oc login -u system:admin

echo "Starting EAP builds" >> conc_builds.out
create_eap_projects
wait_for_build_completion
run_builds
delete_projects
wait_for_project_termination
echo "Finished EAP builds" >> conc_builds.out
cat conc_builds.out
