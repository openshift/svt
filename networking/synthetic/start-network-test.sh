#!/bin/bash
#set -x
################################################
## Auth=vlaad@redhat.com
## Desription: Running network tests without manual involvement.
##
################################################

function wait_for_project_delete {
    uperfprojects=`oc get projects | grep uperf | wc -l`

    while [ 0 -lt $uperfprojects ]
    do
     uperfprojects=`oc get projects | grep uperf | wc -l`
     echo $uperfprojects
     if [ 0 -eq $uperfprojects ]
     then
       break
     else
    	sleep 60
     fi
    done
    }
        
cur_dir=`pwd`
master=`cat config.yaml |egrep 'master:' | awk -F: '{print $2}'`
nodes=`cat config.yaml |egrep 'nodes:' | awk -F: '{print $2}'`
version=`cat config.yaml |egrep 'version:' | awk -F: '{print $2}'`

i=0;
for host in ${nodes//,/ }
do
  nodes_array[i]=${host// /}
  let i=i+1;
done

for var in 1 2 4 8
do

    echo "INFO : $(date) #################### loopback on master for pod - $var pods ####################"
    python network-test.py podIP --master $master --pods $var --version $version
    sleep 120
    wait_for_project_delete

    echo "INFO : $(date) #################### loopback on master for svc - $var pods ####################"
    python network-test.py svcIP --master $master --pods $var --version $version
    sleep 120
    wait_for_project_delete

    echo "INFO : $(date) #################### cross host on master to node for pod - $var pods ####################"
    python network-test.py podIP --master $master --node ${nodes_array[0]} --pods $var --version $version
    sleep 120
    wait_for_project_delete

    echo "INFO : $(date) #################### cross host on master to node for svc - $var pods ####################"
    python network-test.py svcIP --master $master --node ${nodes_array[0]} --pods $var --version $version
    sleep 120
    wait_for_project_delete
	
    echo "INFO : $(date) #################### cross host on node to node for pod - $var pods ####################"
    python network-test.py podIP --master $master --node ${nodes_array[0]} ${nodes_array[1]} --pods $var --version $version
    sleep 120
    wait_for_project_delete

    echo "INFO : $(date) #################### cross host on node to node for svc - $var pods ####################"
    python network-test.py svcIP --master $master --node ${nodes_array[0]} ${nodes_array[1]} --pods $var --version $version
    sleep 120
    wait_for_project_delete

done
