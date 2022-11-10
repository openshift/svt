#/!/bin/bash
#set -x
################################################
## Auth=prubenda@redhat.com
## Desription: Script for running bulk delete
## of empty and loaded projects and comparing times
################################################

source ../common.sh
source ../../utils/run_workload.sh
source ../custom_workload_env.sh
source common_func.sh
source bulk_delete_env.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export blank_projects_config="${DIR}/../../kubeburner-object-templates/blank-projects-config.yml"
export loaded_projects_config="${DIR}/../../kubeburner-object-templates/loaded-projects-config.yml"
delete_output=bulk_delete.out
rm -rf $delete_output

export WORKLOAD_TEMPLATE=$blank_projects_config
echo "=====Empty projects======"  >> $delete_output
export JOB_ITERATION=500
run_workload

echo "Deleting 500 empty projects\n" >> $delete_output
delete_projects_time_to_file kube-burner-job $delete_output

export JOB_ITERATION=1000
run_workload

echo "Deleting 1000 empty projects\n" >> $delete_output
delete_projects_time_to_file kube-burner-job $delete_output

export JOB_ITERATION=5000
run_workload

echo "Deleting 5000 empty projects\n" >> $delete_output
delete_projects_time_to_file kube-burner-job $delete_output

export WORKLOAD_TEMPLATE=$loaded_projects_config
echo "=====Loaded projects======" >> $delete_output
export JOB_ITERATION=500
run_workload $loaded_projects_config

echo "Deleting 500 loaded projects" >> $delete_output
delete_projects_time_to_file kube-burner-job $delete_output

export JOB_ITERATION=1000
run_workload $loaded_projects_config

echo "Deleting 1000 loaded projects" >> $delete_output
delete_projects_time_to_file kube-burner-job $delete_output

cat $delete_output