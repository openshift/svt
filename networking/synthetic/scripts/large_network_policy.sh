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
sdn_project_count=$(oc get projects | grep sdn | wc -l | xargs)
echo "sdn count $sdn_project_count"
if [[ $sdn_project_count -ne 1 ]]; then
  network_namespace="openshift-ovn"
fi

network_pods=$(oc get pods -n $network_namespace -o name)

echo $network_pods

echo "Manually check dump flows for $network_namespace pods by the following commands"
echo "'oc rsh -n $network_namespace <network_pod>'"
echo "'ovs-ofctl dump-flows br0 -O openflow13 | grep table=80'\n"

echo "When done, delete all projects using 'oc delete project -l purpose=test'"