
function wait_for_pod_creation() {
  name_identifier=$1
  object_type=$2

  COUNTER=0
  creating=$(oc get $object_type -A | grep $name_identifier | egrep -c -e "Pending|Creating|Error" )
  while [ $creating -ne 0 ]; do
    sleep 5
    creating=$(oc get $object_type -A |  grep $name_identifier | egrep -c -e "Pending|Creating|Error")
    echo "$creating $object_type are still not running/completed"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 60 ]; then
      echo "$creating $object_type are still not running/complete after 5 minutes"
      break
    fi
  done
}

function uncordon_all_nodes() {
  worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker= -o name)
  for worker in ${worker_nodes}; do
    oc adm uncordon $worker
  done
}


function wait_for_descheduler_to_run() {
  kube_desch_name=$(oc get KubeDescheduler -n openshift-kube-descheduler-operator -o name)
  sched_seconds=$(oc get $kube_desch_name -n openshift-kube-descheduler-operator -o jsonpath='{.spec.deschedulingIntervalSeconds}')
  echo "waiting for $sched_seconds seconds for descheduler to run"
  sleep $sched_seconds
}


function get_descheduler_evicted() {
  desched_pod=$(oc get pods -n openshift-kube-descheduler-operator --no-headers -o name | grep -v operator)
  logs=$(oc logs $desched_pod -n openshift-kube-descheduler-operator --tail=10 |  grep 'Number of evicted pods')
  echo "$logs"
}
