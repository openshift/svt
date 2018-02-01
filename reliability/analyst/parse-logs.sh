#!/bin/bash
#set -x
################################################
## Auth=vlaad@redhat.com
## Desription: starts the ruby script.
################################################
cur_dir=`pwd`
master=`sed -n 's/master: //p' ../config/config.yaml`
master=${master// /}
masters=`sed -n 's/masters: //p' ../config/config.yaml`
masters=${masters//,/ }
nodes=`sed -n 's/nodes: //p' ../config/config.yaml`
nodes=${nodes//,/ }
etcds=`sed -n 's/etcds: //p' ../config/config.yaml`
etcds=${etcds//,/ }
subdomain=`sed -n 's/subdomain: //p' ../config/config.yaml`
subdomain=`echo $subdomain`

#cleanup old log files if they exist
function cleanup_logs
{
  for host in ${nodes//,/ } ; do
    rm -f monitor-node-$host.log
  done
  for host in ${masters//,/ } ; do
    rm -f monitor-master-$host.log
  done
  for host in ${etcds//,/ } ; do
    rm -f monitor-etcd-$host.log
  done

  rm -rf results
}

function cleanup_results
{
  for host in ${nodes//,/ } ; do
    rm -f results/os-node-node-data-$host.csv
    rm -f results/docker-node-data-$host.csv
  done
  for host in ${masters//,/ } ; do
    rm -f results/os-node-master-data-$host.csv
    rm -f results/docker-master-data-$host.csv
    rm -f results/os-master-master-data-$host.csv
  done
  #for host in ${etcds//,/ } ; do
  #done
}

#generate logs
function extract_monitor_logs
{
  for host in ${nodes//,/ } ; do
    grep .*monitor-node-$host.*stdout ../logs/reliability.log* | sed -e "s/\[#\]/\n/g" >> monitor-node-$host.log
  done
  for host in ${masters//,/ } ; do
    grep .*monitor-master-$host.*stdout ../logs/reliability.log* | sed -e "s/\[#\]/\n/g" >> monitor-master-$host.log
  done
  for host in ${etcds//,/ } ; do
    grep .*monitor-etcd-$host.*stdout ../logs/reliability.log* | sed -e "s/\[#\]/\n/g" >> monitor-etcd-$host.log
  done

  echo "****************extracting monitoring data done****************"
}

#create csv file from log data
function extract_cpu_mem_data
{
  [ ! -d results ] &&  mkdir results

  #extract node data
  for host in ${nodes//,/ } ; do
    echo "%CPU,%MEM" >> results/os-node-node-data-$host.csv
    grep 'openshift start node' ./monitor-node-$host.log | awk '{print $3 "," $4}' >> results/os-node-node-data-$host.csv
    echo "%CPU,%MEM" >> results/docker-node-data-$host.csv
    grep 'docker daemon.*devicemapper' ./monitor-node-$host.log | awk '{print $3 "," $4}' >> results/docker-node-data-$host.csv
  done

  #extract master data
  for host in ${masters//,/ } ; do
    echo "%CPU,%MEM" >> results/os-node-master-data-$host.csv
    grep 'openshift start node' ./monitor-master-$host.log | awk '{print $3 "," $4}' >> results/os-node-master-data-$host.csv
    echo "%CPU,%MEM" >> results/os-master-master-data-$host.csv
    grep 'openshift start master' ./monitor-master-$host.log | awk '{print $3 "," $4}' >> results/os-master-master-data-$host.csv
    echo "%CPU,%MEM" >> results/docker-master-data-$host.csv
    grep 'docker daemon.*devicemapper' ./monitor-master-$host.log | awk '{print $3 "," $4}' >> results/docker-master-data-$host.csv
  done

  echo "****************extracting csv data done****************"
}

function extract_activity_data
{
  cat /dev/null > results/activity_logs.txt
  echo "User Creation Passed: $(grep -e "Execute: htpasswd.*-> pass" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "User Creation Failed: $(grep -e "Execute: htpasswd: sh.*-> fail" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "User Creation Total: $(grep -e "Execute: htpasswd.*->" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Project Creation Passed: $(grep -e "Execute: oc new-project.*-> pass" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Project Creation Failed: $(grep -e "Execute: oc new-project.*-> fail" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Project Creation Total: $(grep -e "Execute: oc new-project.*->" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "App Creation Passed: $(grep -e "Execute: oc new-app.*-> pass" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "App Creation Failed: $(grep -e "Execute: oc new-app.*-> fail" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "App Creation Total: $(grep -e "Execute: oc new-app.*->" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Start Build Passed: $(grep -e "Execute: oc start-build.*-> pass" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Start Build Failed: $(grep -e "Execute: oc start-build.*-> fail" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Start Build Total: $(grep -e "Execute: oc start-build.*->" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Scale Up/Down Passed: $(grep -e "Execute: oc scale.*-> pass" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Scale Up/Down Failed: $(grep -e "Execute: oc scale.*-> fail" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Scale Up/Down Total:  $(grep -e "Execute: oc scale.*->" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Login Passed: $(grep -e "Execute: oc login.*-> pass" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Login Failed: $(grep -e "Execute: oc login.*-> fail" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Login Total: $(grep -e "Execute: oc login.*->" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "User Deletion Passed: $(grep -e "Execute: oc delete user.*-> pass" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "User Deletion Failed: $(grep -e "Execute: oc delete user.*-> fail" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "User Deletion Total: $(grep -e "Execute: oc delete user.*->" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Project Deletion Passed: $(grep -e "Execute: oc delete project.*-> pass" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Project Deletion Failed: $(grep -e "Execute: oc delete project.*-> fail" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Project Deletion Total: $(grep -e "Execute: oc delete project.*->" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Application Access Passed $(grep -e "Execute: curl.*${subdomain}.*-> pass" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Application Access Failed $(grep -e "Execute: curl.*${subdomain}.*-> fail" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "Application Access Total $(grep -e "Execute: curl.*${subdomain}.*->" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "DS Scale Up Passed $(grep -e "DS Scale up complete" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "DS Scale Up Failed $(grep -e "DS Scale up failed" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "DS Scale Up Total $(grep -e "DS Scale up" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "DS Scale Down Passed $(grep -e "DS Scale down complete" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "DS Scale Down Failed $(grep -e "DS Scale down failed" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt
  echo "DS Scale Down Total $(grep -e "DS Scale down" ../logs/reliability.log* | wc -l)" >> results/activity_logs.txt

  echo "****************extracting activity data done****************"
}

########Main##################
cleanup_logs
cleanup_results
extract_monitor_logs
extract_cpu_mem_data
extract_activity_data
