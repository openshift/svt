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

for var in 1 2 4 8
do

    echo "INFO : $(date) #################### loopback on master for pod - $var pods ####################"
    python network-test.py podIP --master $master --pods $var
    sleep 200

    echo "INFO : $(date) #################### loopback on master for svc - $var pods ####################"
    python network-test.py svcIP --master $master --pods $var
    sleep 200

    echo "INFO : $(date) #################### cross host on master to node for pod - $var pods ####################"
    python network-test.py podIP --master $master --node ${nodes_array[0]} --pods $var
    sleep 200

    echo "INFO : $(date) #################### cross host on master to node for svc - $var pods ####################"
    python network-test.py svcIP --master $master --node ${nodes_array[0]} --pods $var
    sleep 200

    echo "INFO : $(date) #################### cross host on node to node for pod - $var pods ####################"
    python network-test.py podIP --master $master --node ${nodes_array[0]} ${nodes_array[1]} --pods $var
    sleep 200

    echo "INFO : $(date) #################### cross host on node to node for svc - $var pods ####################"
    python network-test.py svcIP --master $master --node ${nodes_array[0]} ${nodes_array[1]} --pods $var
    sleep 200

done