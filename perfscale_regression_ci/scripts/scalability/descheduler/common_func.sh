
function wait_for_pod_creation() {
  COUNTER=0
  creating=$(oc get pods -A | grep $1 | egrep -c -e "Pending|Creating|Error" )
  while [ $creating -ne 0 ]; do
    sleep 5
    creating=$(oc get pods -A |  grep $1 | egrep -c -e "Pending|Creating|Error")
    echo "$creating pods are still not running/completed"
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 60 ]; then
      echo "$creating pods are still not running/complete after 5 minutes"
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
  #desched_pod=$(oc get pods -n openshift-kube-descheduler-operator --no-headers -o name | grep cluster)
  desched_pod=$(oc get pods -n openshift-kube-descheduler-operator --no-headers -o name | grep -v operator)
  logs=$(oc logs $desched_pod -n openshift-kube-descheduler-operator --tail=10 |  grep 'Number of evicted pods')
  echo "$logs"
}

#
function edit_descheduler() {
  kube_desch_name=$(oc get KubeDescheduler -n openshift-kube-descheduler-operator -o name)
  #oc patch??
  sched_seconds=$(oc get KubeDescheduler $kube_desch_name -n openshift-kube-descheduler-operator -o jsonpath='{.spec.deschedulingIntervalSeconds}')
}


function get_node_name() {
  worker_name=$(echo $1 | rev | cut -d/ -f1 | rev)
  echo "$worker_name"
}

function get_pod_count() {
  worker_name=$(get_node_name $2)
  pod_count=$(oc get pods -o wide -A | grep $1 | grep $worker_name -c | xargs)
  echo "$pod_count"

}
