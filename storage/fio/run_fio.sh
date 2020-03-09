#!/bin/bash

# Variables:
NODE_SELECTOR_KEY=$(cat external_vars.yaml | grep -v '#' | grep NODE_SELECTOR_KEY | cut -d ' ' -f 2)
NODE_SELECTOR_VALUE=$(cat external_vars.yaml | grep -v '#' | grep NODE_SELECTOR_VALUE | cut -d ' ' -f 2)
SCRIPTS_FOLDER=$(cat external_vars.yaml | grep -v '#' | grep SCRIPTS_FOLDER | cut -d ' ' -f 2)
TEST_PROJECT_NAME=$(cat external_vars.yaml | grep -v '#' | grep TEST_PROJECT_NAME | cut -d ' ' -f 2)
VOLUME_CAPACITY=$(cat external_vars.yaml | grep -v '#' | grep VOLUME_CAPACITY | cut -d ' ' -f 2)
STORAGE_CLASS_NAME=$(cat external_vars.yaml | grep -v '#' | grep STORAGE_CLASS_NAME | cut -d ' ' -f 2)
IMAGE=$(cat external_vars.yaml | grep -v '#' | grep IMAGE | cut -d ' ' -f 2)
CLEANING_AFTER_TEST=$(cat external_vars.yaml | grep -v '#' | grep CLEANING_AFTER_TEST | cut -d ' ' -f 2)

echo "NODE_SELECTOR_KEY:            $NODE_SELECTOR_KEY"
echo "NODE_SELECTOR_VALUE:          $NODE_SELECTOR_VALUE"
echo "SCRIPTS_FOLDER:               $SCRIPTS_FOLDER"
echo "TEST_PROJECT_NAME:            $TEST_PROJECT_NAME"
echo "VOLUME_CAPACITY:              $VOLUME_CAPACITY"
echo "STORAGE_CLASS_NAME:           $STORAGE_CLASS_NAME"
echo "IMAGE:                        $IMAGE"
echo "CLEANING_AFTER_TEST:          $CLEANING_AFTER_TEST"

# Functions
function cleaning_after_test {
  oc project default
  oc delete project $TEST_PROJECT_NAME
  oc delete scc fio
  for node in $(oc get nodes | grep worker | cut -d ' ' -f 1)
  do
    oc label node $node $NODE_SELECTOR_KEY-
  done
}

function wait_until_the_pod_is_ready {
  local project
  project=$1
  local pod
  pod=$2
  local timeout
  timeout=$3
  local interval
  interval=$4

  local start_time
  start_time=$(date +%s)

  local ready_pods
  while (( ($(date +%s) - ${start_time}) < ${timeout} ));
  do
    ready_pods=$(oc get pod -n ${project} | grep ${pod} | grep -v deploy | grep Running | grep -c 1/1)
    if [[ "${ready_pods}" == "1" ]]; then
      MY_TIME=$(($(date +%s) - ${start_time}))
      echo "pod ${pod} is ready!"
      break
    fi
    echo "pod ${pod} is not ready yet ... waiting ${interval} seconds"
    sleep ${interval}
  done
}

# FIO WORKLOAD
chmod +x files/scripts/*.*

# Adding labels to workers
for node in $(oc get nodes | grep worker | cut -d ' ' -f 1)
do
  oc label node $node --overwrite $NODE_SELECTOR_KEY=$NODE_SELECTOR_VALUE
done

# Creating new SecurityContextConstraints
if [[ $(oc get scc | grep -c fio) -eq 0 ]]
then
  echo "Creating SecurityContextConstraints"
  oc create -f ./files/content/fio-scc.json
else
  echo "SecurityContextConstraints fio exist"
fi

# Creating new project
oc new-project $TEST_PROJECT_NAME

# Creating new objects
oc process -p "VOLUME_CAPACITY=$VOLUME_CAPACITY" -p "STORAGE_CLASS_NAME=$STORAGE_CLASS_NAME" -p "IMAGE=$IMAGE" -p "NS_KEY=$NODE_SELECTOR_KEY" -p "NS_VALUE=$NODE_SELECTOR_VALUE" -f "./files/content/fio-pod-pv.json" | oc create --namespace=$TEST_PROJECT_NAME -f -
wait_until_the_pod_is_ready $TEST_PROJECT_NAME fio 300 10
working_pod=$(oc get pod -n $TEST_PROJECT_NAME -o wide --no-headers | grep -v deploy | grep Running | awk '{print $1}')
echo "Working pod: $working_pod"

# Coping files:
echo "Preparing pod to run fio test"
oc exec -n $TEST_PROJECT_NAME $working_pod -- rm -rfv "${SCRIPTS_FOLDER}"
oc exec -n $TEST_PROJECT_NAME $working_pod -- mkdir "${SCRIPTS_FOLDER}"
oc cp -n $TEST_PROJECT_NAME "./files/scripts/fio.sh" "$working_pod:${SCRIPTS_FOLDER}"
echo "Pod is ready to rock!"

# Running workload
start_time=`date +%s`

oc exec -n $TEST_PROJECT_NAME $working_pod -- bash "${SCRIPTS_FOLDER}/fio.sh" | tee ${TEST_PROJECT_NAME}_${STORAGE_CLASS_NAME}.log

end_time=`date +%s`
total_time=`echo $end_time - $start_time | bc`
echo "Total time : $total_time"

# Cleaning after test
if [[ "${CLEANING_AFTER_TEST}" == "true" ]]
then
  cleaning_after_test
fi
