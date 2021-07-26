node1=""
node2=""
node3=""

source ./common_func.sh

worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker= -o name)
i=0
for worker in ${worker_nodes}; do
  echo "worker nodes ----  $worker"
  if [[ $i -eq 0 ]]; then
    node1=$worker
  elif [[ $i -eq 1 ]]; then
    node2=$worker
    oc adm cordon $worker
  else
    oc adm cordon $worker
  fi
  i=$((i+1))
done

oc create -f content/constrained_pod.yaml

oc create -f content/demo_pod.yaml

oc create -f content/demo_pod.yaml

wait_for_pod_creation mypod-constrained

wait_for_pod_creation mypod

oc adm cordon $node1
oc adm uncordon $node2

oc create -f content/demo_pod.yaml

wait_for_pod_creation mypod

worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker= -o name)
i=0
last_worker=""
for worker in ${worker_nodes}; do
  if [[ $i -eq 0 ]]; then
    oc label $worker test-zone=zoneA --overwrite=true
  elif [[ $i -eq 1 ]]; then
    oc label $worker test-zone=zoneB --overwrite=true
  else
    oc label $worker test-zone=zoneC --overwrite=true
  fi
  i=$((i+1))
done

oc get pods -o wide

uncordon_all_nodes

#wait 5 minutes

# get tail of logs from cluster-* pod in -n openshift-kube-descheduler-operator



