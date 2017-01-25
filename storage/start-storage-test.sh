#!/bin/bash
#set -x
################################################
## Auth=vlaad@redhat.com
## Desription: Running network tests without manual involvement.
##
################################################
       
cur_dir=`pwd`
master=`cat config.yaml |egrep 'master:' | awk -F: '{print $2}'`
nodes=`cat config.yaml |egrep 'nodes:' | awk -F: '{print $2}'`

i=0;
for host in ${nodes//,/ }
do
  nodes_array[i]=${host// /}
  let i=i+1;
done

echo "INFO : $(date) #################### running storage tests ####################"
python storage-test.py fio --master $master --node ${nodes_array[0]}
sleep 10