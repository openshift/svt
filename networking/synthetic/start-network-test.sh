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
##      - remove the config.yaml
##      - copy the public key from svt private repo
##              ( this assumes that the private repo is present already )
##  -- updates  : 09.06.2018
##      - add another intemediate mode
## Modified: akrzos@redhat.com
##  -- updates  : 11.21.2018
##      - allow skipping of registering pbench tools
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
skip_register_pbench=$2

if [ -z $run_mode ];
 then
   echo "INFO : $(date)  No mode specified and hence running the INTERMEDIATE suite of tests"
   run_mode="INT"
elif [ "$run_mode" != "FULL" ] && [ "$run_mode" != "CI" ] && [ "$run_mode" != "INT" ]
 then
   echo "ERROR : Incorrect mode specified. Permissible mode values [ FULL / CI / INT ] "
   echo " Usage: "
   echo "   ./start-network-test.sh << mode >> << skip directive >>"
   exit 1
fi
if [ -z $skip_register_pbench ];
 then
   echo "INFO : $(date) skip_register_pbench defaulting to false"
   skip_register_pbench=""
elif [ "$skip_register_pbench" != "SKIP" ]
 then
  echo "ERROR : Incorrect skip directive specified. Permissible skip directive value is [ SKIP ] "
  echo " Usage: "
  echo "   ./start-network-test.sh << mode >> << skip directive >>"
  exit 1
else
   skip_register_pbench="--skip"
fi


echo "INFO : $(date) ###### STARTING NETWORK TESTS: $run_mode ######"

# copy the public key from the svt private repo
cp /root/svt-private/image_provisioner/id_rsa_perf.pub id_rsa.pub

# parse the master and nodes from the config file
#cur_dir=`pwd`
#master=`cat config.yaml |egrep 'master:' | awk -F: '{print $2}'`
#nodes=`cat config.yaml |egrep 'nodes:' | awk -F: '{print $2}'`
masters=`oc get nodes | grep master | awk '{print $1}'`
nodes=`oc get nodes | grep ' compute' | awk '{print $1}'`

# make the master schedulable --no longer needed--
#oc adm manage-node --schedulable=true ${master}

i=0;
for master in ${masters//,/ }
do
  masters_array[i]=${master// /}
  let i=i+1;
done

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

pods_var=""

echo "The master node is: ${masters_array[0]} "
echo "Node one is: ${nodes_array[0]} "
echo "Node two is: ${nodes_array[1]} "

if [ "$run_mode" == "FULL" ];
 then
  echo "INFO : $(date) #################### node to node  ####################"
  # run the node node tests
  python network-test.py nodeIP --master ${masters_array[0]} --node ${nodes_array[0]} ${nodes_array[1]} $skip_register_pbench

  # prepare the pods variable for running the network tests
  pods_var="1"
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

elif [ "$run_mode" == "INT" ];
   then
    echo "INFO : $(date) #################### node to node  ####################"
    # run the node node tests
    python network-test.py nodeIP --master ${masters_array[0]} --node ${nodes_array[0]} ${nodes_array[1]} $skip_register_pbench

    # prepare the pods variable for running the network tests
    pods_var=$[10#${nprocs}-2]
    procs=$[10#${nprocs}]
    over_nprocs=$[10#${nprocs}+2]
    if [ "$pods_var" -gt "0" ];
     then
      pods_var="$pods_var $procs $over_nprocs"
    elif [ "$pods_var" -eq "0" ];
     then
      pods_var="1"
      pods_var="$pods_var $procs $over_nprocs"
    else
     pods_var="$procs $over_nprocs"
    fi

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
    python network-test.py podIP --master ${masters_array[0]} --pods $var $skip_register_pbench
    wait_for_project_delete
    sleep 5

    echo "INFO : $(date) ################# loopback on master for svc - $var pods ###################"
    python network-test.py svcIP --master ${masters_array[0]} --pods $var $skip_register_pbench
    wait_for_project_delete
    sleep 5

    echo "INFO : $(date) ################ cross host on master to node for pod - $var pods ##########"
    python network-test.py podIP --master ${masters_array[0]} --node ${nodes_array[0]} --pods $var $skip_register_pbench
    wait_for_project_delete
    sleep 5

    echo "INFO : $(date) ################ cross host on master to node for svc - $var pods ###########"
    python network-test.py svcIP --master ${masters_array[0]} --node ${nodes_array[0]} --pods $var $skip_register_pbench
    wait_for_project_delete
    sleep 5

    echo "INFO : $(date) ############### cross host on node to node for pod - $var pods ##############"
    python network-test.py podIP --master ${masters_array[0]} --node ${nodes_array[0]} ${nodes_array[1]} --pods $var $skip_register_pbench
    wait_for_project_delete
    sleep 5

    echo "INFO : $(date) ############## cross host on node to node for svc - $var pods ###############"
    python network-test.py svcIP --master ${masters_array[0]} --node ${nodes_array[0]} ${nodes_array[1]} --pods $var $skip_register_pbench
    wait_for_project_delete
    sleep 5
  elif [ "$run_mode" == "INT" ];
   then

    samples="2"

    echo "INFO : $(date) ############### cross host on node to node for pod - $var pods ##############"
    python network-test.py podIP --master ${masters_array[0]} --node ${nodes_array[0]} ${nodes_array[1]} --pods $var -t $samples $skip_register_pbench
    wait_for_project_delete
    sleep 5

    echo "INFO : $(date) ############## cross host on node to node for svc - $var pods ###############"
    python network-test.py svcIP --master ${masters_array[0]} --node ${nodes_array[0]} ${nodes_array[1]} --pods $var -t $samples $skip_register_pbench
    wait_for_project_delete
    sleep 5

  else

    tcp_tests="stream"
    udp_tests="rr"
    msg_sizes="16384"
    samples="1"

    echo "INFO : $(date) ############### cross host on node to node for pod with $var pods $msg_sizes msg size and $samples samples ##############"
    python network-test.py podIP -m ${masters_array[0]} -n ${nodes_array[0]} ${nodes_array[1]} -p $var -a $tcp_tests -b $udp_tests -s $msg_sizes -t $samples $skip_register_pbench
    wait_for_project_delete
    sleep 5

    echo "INFO : $(date) ############## cross host on node to node for svc - $var pods $msg_sizes msg size and $samples samples ###############"
    python network-test.py svcIP -m ${masters_array[0]} -n ${nodes_array[0]} ${nodes_array[1]} -p $var -a $tcp_tests -b $udp_tests -s $msg_sizes -t $samples $skip_register_pbench
    wait_for_project_delete
    sleep 5

  fi

done
