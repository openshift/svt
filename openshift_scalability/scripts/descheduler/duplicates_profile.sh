worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker= -o name)
#i=0
#last_worker=""
#first_worker=""
#middle_worker=""
#scale_num=190
for worker in ${worker_nodes}; do
  if [[ $i -eq 0 ]]; then
    first_worker=$worker
  elif [[ $i -eq 1 ]]; then
    oc adm cordon $worker
    middle_worker=$worker
  elif [[ $i -eq 2 ]]; then
    oc adm cordon $worker
    last_worker=$worker
  fi
  i=$((i + 1))
done
source ./common_func.sh

### creates hello-1 pods
oc create deployment hello-first --image=gcr.io/google-containers/pause-amd64:3.0
# oc edit dc hello and change the replica to 12
oc scale --replicas=$scale_num deployment/hello-first

wait_for_pod_creation hello-first

oc adm cordon $first_worker
oc adm uncordon $middle_worker

# create hello pods
oc create deployment hello-second --image=gcr.io/google-containers/pause-amd64:3.0
oc scale --replicas=$scale_num deployment/hello-second
wait_for_pod_creation hello-second

oc adm cordon $middle_worker
oc adm uncordon $last_worker


# create hello pods
oc create deployment hello-third --image=gcr.io/google-containers/pause-amd64:3.0
oc scale --replicas=$scale_num deployment/hello-third

#wait till pods are running
wait_for_pod_creation hello-third

uncordon_all_nodes

wait_for_descheduler_to_run

get_descheduler_evicted

final_status="PASS"
deployment_list=('hello-first' 'hello-second' 'hello-third')
for deployment in "${deployment_list[@]}"; do
  for worker in ${worker_nodes}; do
    pod_count=$(get_pod_count $deployment $worker)
    echo "$pod_count $deployment pods on $worker "
    if [[ $pod_count -eq 190 ]]; then
      final_status="FAIL"
    fi
  done
  echo "\n"
done

echo "Duplicates profile status: $final_status"