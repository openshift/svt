
worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker= -o name)

for worker in ${worker_nodes}; do
  oc label $worker test-zone= --overwrite
  i=$((i+1))
done

source ./common_func.sh
uncordon_all_nodes

delete_eap_pods

oc delete rc --all -n default
oc delete dc --all -n default
oc delete deployment --all -n default
oc delete pvc --all -n default
oc delete pv --all -n default

oc delete pods --all -n default --wait=false
wait_for_pod_deletion "hello"
wait_for_pod_deletion "rcexlc"
wait_for_pod_deletion "rcexpv"

oc delete project -l purpose=test
