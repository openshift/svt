node=""
worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker= -o name)
i=0
last_worker=""
first_worker=""
for worker in ${worker_nodes}; do
  if [[ $i -eq 0 ]]; then
    first_worker=$worker
    oc debug $worker -- chroot /host mkdir /mnt/data
  else
    oc adm cordon $worker
    last_worker=$worker
  fi
  i=$((i + 1))
done

source ./common_func.sh

##have to have following profiles set
##profiles:
##    - TopologyAndDuplicates
##    - EvictPodsWithLocalStorage

oc create -f content/rc_local_storage.yaml

oc create -f content/pvc_nfs.yaml

oc create -f content/rc.yaml

wait_for_pod_creation rcex
wait_for_pod_creation rcexlc

#only rcexlc pods should get evicted
oc get pods -o wide

uncordon_all_nodes

#set to same as decheduler timing
wait_for_descheduler_to_run

get_descheduler_evicted
worker_nme=$(get_node_name $first_worker)

echo $worker_nme
pod_count=$(get_pod_count rcexpv $first_worker)
echo "$pod_count rcexpv pods on $first_worker"
if [[ $pod_count -ge 110 ]]; then
  echo "PASS"
else
  echo "FAIL, expected 110 pods still on worker node"
fi


lc_pod_count=$(get_pod_count rcexlc $first_worker)
echo "$lc_pod_count rcexlc pods on $first_worker"

if [[ $lc_pod_count -lt 110 ]]; then
  echo "PASS"
else
  echo "FAIL, expected there to be less than 110 pods on worker node"
fi