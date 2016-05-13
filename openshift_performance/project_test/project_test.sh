#!/bin/bash

create_project()
{
  for i in `seq 1 $num`
  do
    (time -p oadm new-project project$i --admin=test$i) 2>> record/project$num &
  done
}

clean_projects()
{
  for i in `seq 1 $num`
  do
    oc delete project project$i 
  done

  while true
  do
    sleep 10
    str1=$( oc get project |grep Terminating)

    if [ -z "$str1" ]
    then
      break
    else
      echo "Still Terminating..."
    fi

  done  
  
  echo "All projects cleaned up!!!"
}

generate_avg()
{
for i in $(cat test_cal)
do
  echo "The avg time for creating $i projects is:" >> test_result
  cat record/project$i | grep real | awk '{sum+=$2}END{print sum/NR}'  >> test_result
done
}


[ -d ./record ] || mkdir ./record

for (( num=10; num<=100; num+=10 ))
do
  echo "**********Test Result***************">> record/project$num
  echo $num >> test_cal

  echo "Ready for creating $num projects"

  create_project 

  echo "Wait for projects created..."

  sleep 300

  clean_projects
  sleep 300
done

generate_avg
echo "Check test_result file for the final test result"
