#/!/bin/bash
#set -x
################################################
## Auth=vlaad@redhat.com
## Desription: Script for running concurrent 
## build tests.
################################################
master=$1
#build_array=(1 5 10 20 30 40 50)
build_array=(1 8 15 30 45 60 75)
#app_array=("cakephp" "eap" "django" "nodejs")
app_array=("django")
# this number should be equal to the number of the created projects
readonly PROJECT_NUM=75

function delete_projects()
{
  echo "deleting projects"
  oc delete project -l purpose=test --wait=false
}

function create_projects()
{
  python ../../../openshift_scalability/cluster-loader.py -f $1
}

function prepare_builds_file()
{
  bc_name=`oc get bc -n  svt-$1-0 --no-headers | awk {'print $1'}`
  local running_build_file
  running_build_file="../content/running-builds.json"
  # generate running-builds.json on the fly
  printf '%s\n' "[" > "${running_build_file}"
  for (( c=0; c<"${PROJECT_NUM}"; c++ ))
  do
    if [[ "$c" == $((PROJECT_NUM - 1)) ]]; then
      printf '%s\n' "{\"namespace\":\"svt-$1-${c}\", \"name\":\"$bc_name\"}" >> "${running_build_file}"
    else
      printf '%s\n' "{\"namespace\":\"svt-$1-${c}\", \"name\":\"$bc_name\"}," >> "${running_build_file}"
    fi
  done
  printf '%s' "]" >> "${running_build_file}"
}

function run_builds()
{
  for i in "${build_array[@]}"
  do
    echo "running $i $1 concurrent builds"
    python ../../ose3_perf/scripts/build_test.py -z -n 2 -r $i -f ../content/running-builds.json >> conc_builds_$1.out
    sleep 30
  done
}

function wait_for_build_completion()
{
  running=`oc get pods --all-namespaces | grep svt | grep build | grep Running | wc -l`
  while [ $running -ne 0 ]; do
    sleep 5
    running=`oc get pods --all-namespaces | grep svt | grep build | grep Running | wc -l`
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

function clean_docker_images()
{
  oc login -u redhat -p redhat
  oadm prune images --keep-tag-revisions=1 --keep-younger-than=5m --confirm
  oc login -u system:admin
  oadm prune builds --orphans --keep-complete=0 --keep-failed=0 --keep-younger-than=0m --confirm

  echo "docker rmi -f $(docker images | grep proj | awk '{print $3}')" >> clean-docker.sh
  chmod 777 clean-docker.sh
  ssh root@$(oc get nodes --show-labels | grep primary | head -1 | awk '{print $1}') < clean-docker.sh >> clean-docker.out
  ssh root@$(oc get nodes --show-labels | grep primary | tail -n 1 | awk '{print $1}') < clean-docker.sh >> clean-docker.out
}

rm -rf *.out

#setup user for build tests
#oc login -u system:admin
#htpasswd -b /etc/origin/htpasswd redhat redhat
#oadm policy add-cluster-role-to-user admin redhat
#oadm policy add-cluster-role-to-user system:image-pruner redhat

for app in "${app_array[@]}"
do
  #oc login -u system:admin
  echo "Starting $app builds" >> conc_builds_$app.out
  create_projects "../content/conc_builds_$app.yaml"
  wait_for_build_completion
  prepare_builds_file $app
  run_builds $app
  delete_projects
  wait_for_project_termination
  echo "Finished $app builds" >> conc_builds_$app.out
  cat conc_builds_$app.out
#  clean_docker_images
done

for proj in "${app_array[@]}"
do
  echo "================ Average times for $proj app =================" >> conc_builds_results.out
  grep "Average build time, all good builds" conc_builds_$proj.out >> conc_builds_results.out
  grep "Average push time, all good builds" conc_builds_$proj.out >> conc_builds_results.out
  grep "Good builds included in stats" conc_builds_$proj.out >> conc_builds_results.out
  echo "==============================================================" >> conc_builds_results.out
done

cat conc_builds_results.out
