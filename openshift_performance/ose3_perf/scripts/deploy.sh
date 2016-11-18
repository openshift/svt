#!/bin/bash

project_pre=$1
dc=$2
max=100

for i in $(eval echo {1..$max}); do
   echo "Deleting $dc from $project_pre$i (errors are OK)"
   oc delete dc $dc -n $project_pre$i
done

for  num in $(eval echo {5..100..5})  ; do 
   
   num_running=`oc get pods --show-all=false --all-namespaces=true | grep $dc | wc -l`
   while [ $num_running -ne 0 ]; do
      sleep 3
      num_running=`oc get pods --show-all=false --all-namespaces=true | grep $dc |  wc -l`
      echo "Pre-flight: waiting for 0, have $num_running"
   done
   for i in $(eval echo {1..$num}); do
      oc create -f ${dc}.json -n $project_pre$i
   done
   while [ $num_running -lt $num ]; do
      sleep 3
      num_running=`oc get pods --show-all=false --all-namespaces=true | grep -v "deploy" | grep -E "$dc\-1\-.*\s+1\/1\s+Running" | wc -l`
      echo "Startup:  waiting for $num, have $num_running"
   done
   sleep 10
   start_time=`date +%s`
   for i in $(eval echo {1..$num}); do
      oc rollout latest $dc -n $project_pre$i
   done

   num_running=0
   while [ $num_running -lt $num ]; do
      sleep 3
      num_running=`oc get pods --show-all=false --all-namespaces=true | grep -v "deploy" | grep -E "$dc\-2\-.*\s+1\/1\s+Running" | wc -l`
      echo "Deploy: waiting for $num, have $num_running"
   done
   stop_time=`date +%s`
   total_time=`echo $stop_time - $start_time | bc`
   echo "Time for $num concurrent deployments : $total_time"
   echo "Time for $num concurrent deployments : $total_time" >> deploy.out
   
   for i in $(eval echo {1..$num}); do
      oc delete -n $project_pre$i dc/$dc
   done  
done
