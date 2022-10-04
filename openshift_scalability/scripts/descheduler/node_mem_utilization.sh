worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker= -o name)
i=0
last_worker=""
first_worker=""

for worker in ${worker_nodes}; do
  if [[ $i -eq 0 ]]; then
    first_worker=$worker
  else
    oc adm cordon $worker
    last_worker=$worker
  fi
  i=$((i + 1))
done
source ./common_func.sh

MY_CONFIG=../../config/pod_utilization.yaml
python --version
python ../../cluster-loader.py -f $MY_CONFIG

wait_for_pod_creation eap64-mysql

uncordon_all_nodes

wait_for_descheduler_to_run

get_descheduler_evicted

for worker in ${worker_nodes}; do
  pod_count=$(get_pod_count eap64-mysql $worker)
  echo "$pod_count pods on $worker"
done

worker_name=$(get_node_name $first_worker)
first_node_count=$(oc get pods -o wide -A | grep 'eap64-mysql' | grep Running | grep $first_worker -c | xargs)
if [[ $first_node_count -ge 18 ]]; then
  echo "FAIL"
else
  echo "PASS"
fi
