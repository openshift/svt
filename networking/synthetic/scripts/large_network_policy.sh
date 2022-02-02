#/!/bin/bash
################################################
## Auth=prubenda@redhat.com
## Desription: Script for creating pause deployments and adding network policies
################################################

pause_deploy_file="../../../openshift_scalability/config/pause_deployment.yaml"

function create_projects() {
  echo "create projects variable $1"
  python ../../../openshift_scalability/cluster-loader.py -f $1
}

create_projects $pause_deploy_file

for i in $(oc get projects | grep pause | grep -Eo 'pause\S*');
do
  echo "$i"
  oc create -f ../content/allow_default_network_policy.yaml -n "$i"
done


network_namespace="openshift-sdn"
container_name="sdn"
sdn_project_count=$(oc get projects | grep sdn | wc -l | xargs)
echo "sdn count $sdn_project_count"
if [[ $sdn_project_count -ne 1 ]]; then
  network_namespace="openshift-ovn-kubernetes"
  container_name="ovnkube-node"
fi

network_pods=$(oc get pods -n $network_namespace -o name)

echo $network_pods

total_policies=0
for pod in $network_pods;
do
   count=$(oc exec $pod -n $network_namespace -c $container_name -- ovs-ofctl dump-flows br0 -O openflow13 | grep table=80 | wc -l | xargs)
   echo "$count"
   total_policies=$(($total_policies + $count))
done

echo "Total flows in pods $total_policies"

if [[ $total_policies -ge 5000 ]]; then
  echo "PASS"
else
  echo "FAIL, not enough policies in flow, see https://bugzilla.redhat.com/show_bug.cgi?id=1752636#c61"
fi

echo "When done, delete all projects using 'oc delete project -l purpose=test'"