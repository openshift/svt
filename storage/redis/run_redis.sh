#!/bin/bash 

iteration=$(cat external_vars.yaml | grep -v '#' | grep iteration | cut -d ' ' -f 2)
test_project_name=$(cat external_vars.yaml | grep -v '#' | grep test_project_name | cut -d ' ' -f 2)
test_project_number=$(cat external_vars.yaml | grep -v '#' | grep test_project_number | cut -d ' ' -f 2)
delete_test_project_before_test=$(cat external_vars.yaml | grep -v '#' | grep delete_test_project_before_test | cut -d ' ' -f 2)
storage_class=$(cat external_vars.yaml | grep -v '#' | grep STORAGE_CLASS_NAME | cut -d ' ' -f 2)
redis_password=$(cat external_vars.yaml | grep -v '#' | grep REDIS_PASSWORD | cut -d ' ' -f 2)
redis_version=$(cat external_vars.yaml | grep -v '#' | grep REDIS_VERSION | cut -d ' ' -f 2)
memory_limity=$(cat external_vars.yaml | grep -v '#' | grep MEMORY_LIMIT | cut -d ' ' -f 2)
ycsb_threads=$(cat external_vars.yaml | grep -v '#' | grep ycsb_threads | cut -d ' ' -f 2)
workload=$(cat external_vars.yaml | grep -v '#' | grep workload | cut -d ' ' -f 2)
volume_capacity=$(cat external_vars.yaml | grep -v '#' | grep VOLUME_CAPACITY | cut -d ' ' -f 2)
working_directory=$(pwd)

echo "Iterations:          $iteration"
echo "Test Project Name:   $test_project_name"
echo "Test Project Number: $test_project_number"
echo "Storage Class Name:  $storage_class"
echo "Redis password:      $redis_password"
echo "Redis version:       $redis_version"
echo "Memory Limit:        $memory_limity"
echo "yscb threads:        $ycsb_threads"
echo "Workload:            $workload"
echo "Volume Capacity:     $volume_capacity"
echo "Working directory    $working_directory"

chmod +x files/scripts/*.sh
# Creating OCP objects
bash files/scripts/create-oc-objects.sh $test_project_name $test_project_number $working_directory $delete_test_project_before_test $memory_limity $redis_password $volume_capacity $redis_version $storage_class
echo "Sleep 60 sec..."
sleep 60

bash files/scripts/test-redis-m.sh $test_project_name $test_project_number $iteration $ycsb_threads $workload $working_directory