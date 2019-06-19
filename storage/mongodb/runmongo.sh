#!/bin/bash 

memory_limity=$(cat external_vars.yaml | grep MEMORY_LIMIT | cut -d ' ' -f 2)
ycsb_threads=$(cat external_vars.yaml | grep ycsb_threads | cut -d ' ' -f 2)
working_directory=$(pwd)
workload=$(cat external_vars.yaml | grep workload | cut -d ' ' -f 2)
iterations=$(cat external_vars.yaml | grep iteration | cut -d ' ' -f 2)
recordcount=$(cat external_vars.yaml | grep recordcount | cut -d ' ' -f 2)
operationcount=$(cat external_vars.yaml | grep operationcount | cut -d ' ' -f 2)
storage_class=$(cat external_vars.yaml | grep STORAGE_CLASS_NAME | cut -d ' ' -f 2)
volume_capacity=$(cat external_vars.yaml | grep VOLUME_CAPACITY | cut -d ' ' -f 2)
distribution=$(cat external_vars.yaml | grep distribution | cut -d ' ' -f 2)
test_project_name=$(cat external_vars.yaml | grep test_project_name | cut -d ' ' -f 2)
test_project_number=$(cat external_vars.yaml | grep test_project_number | cut -d ' ' -f 2)
delete_test_project_before_test=$(cat external_vars.yaml | grep delete_test_project_before_test | cut -d ' ' -f 2)
mongodb_user=$(cat external_vars.yaml | grep MONGODB_USER | cut -d ' ' -f 2)
mongodb_password=$(cat external_vars.yaml | grep MONGODB_PASSWORD | cut -d ' ' -f 2)
mongodb_database=$(cat external_vars.yaml | grep MONGODB_DATABASE | cut -d ' ' -f 2)
mongodb_version=$(cat external_vars.yaml | grep MONGODB_VERSION | cut -d ' ' -f 2)


echo "Memory limit:        $memory_limity"
echo "YCSB threads:        $ycsb_threads"
echo "Working directory:   $working_directory"
echo "Workload:            $workload"
echo "Iteration:           $iterations"
echo "Record count:        $recordcount"
echo "Operation count:     $operationcount"
echo "Storage class:       $storage_class"
echo "Volume Capacity:     $volume_capacity"
echo "Distribution:        $distribution"
echo "Test Project Name:   $test_project_name"
echo "Number of projects:  $test_project_number"
echo "Delete test project: $delete_test_project_before_test"
echo "MongoDB user:        $mongodb_user"
echo "MongoDB password:    $mongodb_password"
echo "MongoDB database:    $mongodb_database"
echo "MongoDB version:     $mongodb_version"

chmod +x files/scripts/*.sh
# Creating OCP objects
bash files/scripts/create-oc-objects.sh $test_project_name $test_project_number $working_directory $delete_test_project_before_test $memory_limity $mongodb_user $mongodb_password $mongodb_database $volume_capacity $mongodb_version $storage_class
echo "Sleep 60 sec..."
sleep 60
bash files/scripts/test-mongo-m-load.sh $test_project_name $test_project_number $iterations $ycsb_threads $workload $recordcount $operationcount $distribution $working_directory
echo "Sleep 60 sec..."
sleep 60
bash files/scripts/test-mongo-m-run.sh $test_project_name $test_project_number $iterations $ycsb_threads $workload $recordcount $operationcount $distribution $working_directory