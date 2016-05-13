#!/bin/bash

project="build"
template_file="application-template-stibuild.json"
#template_file="application-template-dockerbuild.json"
fail="false"
registry=$(oc get svc -n default|grep docker-registry|awk '{print $2}')
output="origin-ruby-sample"
buildSuccess="Pushing $registry:5000/$project/$output:latest image"
#buildSuccess="Pushing $registry:5000/$project"

echo $buildSuccess

function date_process {
  for i in `seq 1 $num`
  do
#   str1=$(oc build-logs -n $project $build_config-$i | sed -n '$p' |grep "Successfully pushed")
    str1=$(oc build-logs -n $project $build_config-$i | grep "$buildSuccess")

    #check whether the sti build is success, if failed, pass the time process part
    if [ -z "$str1" ]
    then
      echo "The $i sti build failed!!" >> record/build-$num
      fail="true"
    else 
      #get the start time and end time of sti build from build log of each build
      time1=$(oc build-logs -n $project $build_config-$i | sed -n '1p' | awk '{print $2}')   
      time1=$(date +%s -d $time1)
      
      time2=$(oc build-logs -n $project $build_config-$i | grep "$buildSuccess" |awk '{print $2}')
      timeb=$time2
      
      time2=$(date +%s -d $time2)
      b_time=$(($time2-$time1))
      
      echo "$i sti build cost:"  >> record/build-$num
      echo "$b_time seconds"  >> record/build-$num
    fi

  done
}

function generate_avg {
  for i in $(cat test_cal)
  do
    success_num1=$(cat record/build-$i | grep seconds | wc -l)
    echo "There's $success_num1 sti build succeed during $i build testing, the avg time of the $success_num1 build is: " >> test_result
    cat record/build-$i | grep seconds | awk '{sum+=$1}END{print sum/NR}'  >> test_result
  done
}

function clean_projects {
  oc delete project $project
  while true
  do
    sleep 5
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


function create_app {
	oc delete project build-parallel
	oadm new-project $project
	oc new-app -f $template_file -n $project
	echo "app $build_config created."
}

function get_bc_info {
    bc=$(oc get bc -n build | sed -n '$p')
    build_config=$(echo $bc|awk '{print $1}')
    build_type=$(echo $bc | awk '{print $2}')
}

function start_build {
	#local startNum = $1
	for num in $(seq 1 1 $1)
	do
		oc start-build $build_config -n $project
	done
}

function building_check {
  while true
  do
    r_build=0

    for i in `seq 1 $num`
    do
      status=$( oc get build/$build_config-$i -n $project|grep "$build_type" |awk '{print $3}')

      if [ $status = "Complete" ]
      then
        let r_build+=1
      elif [ $status = "Failed" ]
      then
        fail="true" 
        let r_build+=1
      fi 
    
     done

    if [ $r_build -eq $num ]
    then
      echo "All $num build are finished now!"
      break
    else
      echo "Waiting all the build to be finished..."
      sleep 5
    fi

  done
}

#main loop
[ -d ./record ] || mkdir ./record

#for num in $(seq 10 10 100)
for num in $(seq 5 5 15)
do
  echo "**********Test Result***************">> record/build-$num
  echo $num >> test_cal

  echo "Create project and apps..."
  create_app
  get_bc_info
  start_build $num

  #wait for the building finished,some build may fail.
  building_check 

  date_process

  if [ $fail = "true" ]
  then
    echo "There's build failed, pls check!!"
    continue
  else
    clean_projects
  fi
 
  sleep 10

done

generate_avg
echo "Check test_result file for the final test result"
cat test_result
