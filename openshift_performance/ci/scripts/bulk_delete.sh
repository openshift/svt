#/!/bin/bash
#set -x
################################################
## Auth=prubenda@redhat.com
## Desription: Script for running bulk delete
## of empty and loaded projects and comparing times
################################################
file_1="../content/conc_proj.yaml"
file_2="../content/pyconfigLoadedProject.yaml"
delete_output=bulk_delete.out
function create_projects()
{
  python ../../../openshift_scalability/cluster-loader.py -f $1
}

function delete_projects() {
  ./delete_projects.sh
}

function rewrite_yaml() {
  python3 -c "import increase_pods; increase_pods.print_new_yaml($1,'$2')"
}

python3 -m pip install ruamel.yaml

rm -if $delete_output

oc version >> $delete_output

oc get machinesets -A >> $delete_output
echo "=====Empty projects======"  >> $delete_output
rewrite_yaml 500 $file_1
create_projects $file_1

echo "Deleting 500 empty projects\n" >> $delete_output
delete_projects >> $delete_output

rewrite_yaml 1000 $file_1
create_projects $file_1

echo "Deleting 1000 empty projects\n" >> $delete_output
delete_projects >> $delete_output

#edit conc_proj to have 5000 projects
rewrite_yaml 5000 $file_1
create_projects $file_1

echo "Deleting 5000 empty projects\n" >> $delete_output
delete_projects >> $delete_output
#
echo "=====Loaded projects======"
rewrite_yaml 500 $file_2
create_projects $file_2

echo "Deleting 500 loaded projects" >> $delete_output
delete_projects >> $delete_output

#edit pyconfigLoadedProject.yaml  to have 1000 projects
rewrite_yaml 1000 $file_2
create_projects $file_2

echo "Deleting 1000 loaded projects" >> $delete_output
delete_projects >> $delete_output

cat $delete_output
