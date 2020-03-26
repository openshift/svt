#!/usr/bin/env bash

test_project_name=$(cat external_vars.yaml | grep test_project_name | cut -d ' ' -f 2)
test_project_number=$(cat external_vars.yaml | grep test_project_number | cut -d ' ' -f 2)
working_folder=$(pwd)
delete_test_project_before_test=$(cat external_vars.yaml | grep delete_test_project_before_test | cut -d ' ' -f 2)
volume_capacity=$(cat external_vars.yaml | grep VOLUME_CAPACITY | cut -d ' ' -f 2)
storage_class_name=$(cat external_vars.yaml | grep STORAGE_CLASS_NAME | cut -d ' ' -f 2)
iteration=$(cat external_vars.yaml | grep iteration | cut -d ' ' -f 2)
test_log_file="/tmp/storage_git_test.log"

echo "Test project name:               $test_project_name"
echo "Test project number:             $test_project_number"
echo "Working folder:                  $working_folder"
echo "Delete test project before test: $delete_test_project_before_test"
echo "Volume capacity:                 $volume_capacity"
echo "Storage class name:              $storage_class_name"
echo "Iteration:                       $iteration"


bash files/scripts/create-oc-objects.sh $test_project_name $test_project_number $working_folder $delete_test_project_before_test $volume_capacity $storage_class_name
echo "Sleep for 60 seconds..."
sleep 60

start_time=`date +%s`

bash files/scripts/test-git-m.sh $test_project_name $test_project_number $iteration $working_folder 2>&1 | tee -a $test_log_file

end_time=`date +%s`
total_time=`echo $end_time - $start_time | bc`
echo "Total time : $total_time"

echo -e "\nTest log file: $test_log_file"