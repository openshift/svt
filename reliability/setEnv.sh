#!/bin/bash
#set -x
################################################
## Auth=anli@redhat.com
## Desription: initial the environment for Reliability testing
## 
################################################
#cur_dir=`pwd`
#clients=`cat config/config.ini |egrep 'client *=' | awk -F= '{print $2}'`
clients=""  # Disable clients until the feature is ready 
master=`sed -n 's/master: //p' config/config.yaml`
master=${master// /}
masters=`sed -n 's/masters: //p' config/config.yaml`
masters=${masters//,/ }
nodes=`sed -n 's/nodes: //p' config/config.yaml`
nodes=${nodes//,/ }
etcds=`sed -n 's/etcds: //p' config/config.yaml`
etcds=${etcds//,/ }
gituser=`sed -n 's/gituser: //p' config/config.yaml`
gituser=${gituser// /}
pbenchserver=`sed -n 's/pbenchserver: //p' config/config.yaml`
pbenchserver=${pbenchserver// /}

function config_local_env()
{
   #Delete generated files from last run if exist.
   rm -rf logs
   rm -rf runtime
   cat /dev/null > config/users.data

   echo "#) Config Local Environment"
   config_runtime_template
}

function config_masters_env()
{
  echo "#) Config Masters Environment $masters"

  for host in ${masters} ; do
    scp -r lib/bin  root@$host:/root
  done

}

function config_nodes_env()
{
  echo "#) Config Nodes Environment"
  for host in ${nodes} ; do
    scp -r lib/bin  root@$host:/root
  done 

}

function config_etcds_env()
{
  echo "#) Config Etcds Environment"
  for host in ${etcds} ; do
    scp -r lib/bin  root@$host:/root
  done

}
function config_local_sshkey()
{
  echo "#) Copy ssh-key to remote host"
  for host in `echo ${client} ${etcds} ${masters} ${nodes}` ; do
    ssh-copy-id root@$host
  done
}


function config_runtime_template()
{
  echo "#) copy openshift keys/template to runtime/"
  [ ! -d logs ] && mkdir logs
  [ ! -d runtime ] && mkdir runtime
  [ ! -d runtime/keys ] && mkdir runtime/keys
  [ ! -d runtime/repos ] && mkdir runtime/repos
  [ ! -d runtime/templates ] && mkdir runtime/templates
  scp -r root@$master:/etc/origin/master/admin.kubeconfig  runtime/keys
  scp -r root@$master:/etc/origin/master/ca.crt  runtime/keys
  scp -r root@$master:/usr/share/openshift/examples/quickstart-templates  runtime/templates
}

function config_pb_reg_tool_set
{
  #clear any previous registration
  pbench-cleanup
  pbench-clear-tools
  for host in ${nodes//,/ } ; do
    pbench-register-tool --name=sar --remote=$host -- --interval=3
    pbench-register-tool --name=pidstat --remote=$host -- --interval=3
    # --patterns=openshift,docker
    pbench-register-tool --name=iostat --remote=$host -- --interval=3
  done
  for host in ${masters//,/ } ; do
    pbench-register-tool --name=sar --remote=$host -- --interval=3
    pbench-register-tool --name=pidstat --remote=$host -- --interval=3
    # --patterns=openshift,docker
    pbench-register-tool --name=iostat --remote=$host -- --interval=3
  done
  for host in ${etcds//,/ } ; do
    pbench-register-tool --name=sar --remote=$host -- --interval=3
    pbench-register-tool --name=pidstat --remote=$host -- --interval=3
    # --patterns=openshift,docker
    pbench-register-tool --name=iostat --remote=$host -- --interval=3
  done
}


########Main##################
#config_local_sshkey
config_local_env
config_masters_env
config_nodes_env
config_etcds_env
config_pb_reg_tool_set