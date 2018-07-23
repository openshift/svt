#!/bin/bash
#set -x
################################################
## Auth=vlaad@redhat.com
## Desription: Running network tests without manual involvement.
##
## Modified: schituku@redhat.com
##  -- added the wait for project delete function
##  -- added node to node scenarios
##  -- changes for issue #448 : 06.06.2018 
##      - add code for running tests based on mode
##      - remove/select test scenarios based on mode  
################################################

function wait_for_project_delete {
    uperfprojects=`oc get projects | grep uperf | wc -l`

    while [ 0 -lt $uperfprojects ]
    do
     uperfprojects=`oc get projects | grep uperf | wc -l`
     echo "Deleting $uperfprojects projects..."
     if [ 0 -eq $uperfprojects ]
     then
       break
     else
    	sleep 5
     fi
    done
    }
        
run_mode=$1

if [ -z $run_mode ];
 then
   echo "INFO : $(date)  No mode specified and hence running the FULL suite of tests"
   run_mode="FULL"
elif [ "$run_mode" != "FULL" ] && [ "$run_mode" != "CI" ]
 then
   echo "ERROR : Incorrect mode specified. Permissible mode values [ FULL / CI ] "
   echo " Usage: "  
   echo "   ./start-network-test.sh << mode >> "  
   exit 1
fi

echo "INFO : $(date) ###### STARTING NETWORK TESTS: $run_mode ######"

# parse the master and nodes from the config file
cur_dir=`pwd`
master=`cat config.yaml |egrep 'master:' | awk -F: '{print $2}'`
nodes=`cat config.yaml |egrep 'nodes:' | awk -F: '{print $2}'`

# make the master schedulable --no longer needed-- 
#oc adm manage-node --schedulable=true ${master}

i=0;
for host in ${nodes//,/ }
do
  nodes_array[i]=${host// /}
  let i=i+1;
done

# get the nprocs of the node
nprocs=`ssh ${nodes_array[0]} grep -c ^processor /proc/cpuinfo` 
#nprocs=4
echo "INFO: $(date) Number of procs on node: $nprocs "

pods_var="1"

if [ "$run_mode" == "FULL" ];
 then
  echo "INFO : $(date) #################### node to node  ####################"
  # run the node node tests
  python network-test.py nodeIP --master $master --node ${nodes_array[0]} ${nodes_array[1]}
  
  # prepare the pods variable for running the network tests
  over_nprocs=$[10#${nprocs}+4]
  for ((procs=0; procs<=$nprocs; procs=$[10#${procs}+2])); do
      if [ $procs -ne 0 ];
       then
         pods_var="$pods_var $procs"
      fi
    done
  pods_var="$pods_var $over_nprocs"
  # wait for the projects from node-node test to get deleted.
  wait_for_project_delete
else
  pods_var=$nprocs
fi

echo "INFO : $(date) ### The tests will be run for the following number of pods: $pods_var #####"
for var in $pods_var
do
  if [ "$run_mode" == "FULL" ];
   then
    echo "INFO : $(date) ################# loopback on master for pod - $var pods ##################"
    python network-test.py podIP --master $master --pods $var
    wait_for_project_delete
    sleep 5

    echo "INFO : $(date) ################# loopback on master for svc - $var pods ###################"
    python network-test.py svcIP --master $master --pods $var
    wait_for_project_delete
    sleep 5

    echo "INFO : $(date) ################ cross host on master to node for pod - $var pods ##########"
    python network-test.py podIP --master $master --node ${nodes_array[0]} --pods $var
    wait_for_project_delete
    sleep 5

    echo "INFO : $(date) ################ cross host on master to node for svc - $var pods ###########"
    python network-test.py svcIP --master $master --node ${nodes_array[0]} --pods $var
    wait_for_project_delete
    sleep 5
  	
    echo "INFO : $(date) ############### cross host on node to node for pod - $var pods ##############"
    python network-test.py podIP --master $master --node ${nodes_array[0]} ${nodes_array[1]} --pods $var
    wait_for_project_delete
    sleep 5

    echo "INFO : $(date) ############## cross host on node to node for svc - $var pods ###############"
    python network-test.py svcIP --master $master --node ${nodes_array[0]} ${nodes_array[1]} --pods $var
    wait_for_project_delete
    sleep 5
  else

    tcp_tests="stream"
    udp_tests="rr"
    msg_sizes="16384"
    samples="1"
    
    echo "INFO : $(date) ############### cross host on node to node for pod with $var pods $msg_sizes msg size and $samples samples ##############"
    python network-test.py podIP -m $master -n ${nodes_array[0]} ${nodes_array[1]} -p $var -a $tcp_tests -b $udp_tests -s $msg_sizes -t $samples 
    wait_for_project_delete
    sleep 5

    echo "INFO : $(date) ############## cross host on node to node for svc - $var pods $msg_sizes msg size and $samples samples ###############"
    python network-test.py svcIP -m $master -n ${nodes_array[0]} ${nodes_array[1]} -p $var -a $tcp_tests -b $udp_tests -s $msg_sizes -t $samples
    wait_for_project_delete
    sleep 5

  fi

done
