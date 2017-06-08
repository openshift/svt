#/!/bin/bash
#set -x
################################################
## Auth=vlaad@redhat.com
## Desription: Script for running concurrent 
## build tests.
################################################
master=$1
build_array=(20 40 50)
app_array=("cakephp" "eap" "nodejs")

function delete_projects()
{
  echo "deleting projects"
  oc delete project -l purpose=test
}

function create_projects()
{
  python ../../../openshift_scalability/cluster-loader.py -f $1
}

function prepare_builds_file()
{
  bc_name=`oc get bc -n  proj0 --no-headers | awk {'print $1'}`
  cp ../content/builds.json ../content/running-builds.json
  sed -i "s/build_name/$bc_name/" ../content/running-builds.json
}

function run_builds()
{
  for i in "${build_array[@]}"
  do
    echo "running $i $1 concurrent builds"
    python ../../ose3_perf/scripts/build_test.py -z -n 2 -r $i -f ../content/running-builds.json
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
    terminating=`oc get projects | grep Terminating | wc -l`
    echo "$terminating projects are still terminating"
  done
}

rm -rf *.out
delete_projects

for proj in "${app_array[@]}"
do
  oc login -u system:admin
  echo "Starting $proj builds" >> conc_builds_$proj.out
  create_projects "../content/conc_builds_$proj.yaml"
  wait_for_build_completion
  prepare_builds_file
  run_builds $proj
  sleep 60
  delete_projects
  wait_for_project_termination
#  echo "Finished $proj builds" >> conc_builds_$proj.out
#  cat conc_builds_$proj.out
done

#for proj in "${app_array[@]}"
#do
#  echo "================ Average times for $proj app =================" >> conc_builds_results.out
#  grep "Average build time, all good builds" conc_builds_$proj.out >> conc_builds_results.out
#  grep "Average push time, all good builds" conc_builds_$proj.out >> conc_builds_results.out
#  grep "Good builds included in stats" conc_builds_$proj.out >> conc_builds_results.out
#  echo "==============================================================" >> conc_builds_results.out
#done

cat conc_builds_results.out
