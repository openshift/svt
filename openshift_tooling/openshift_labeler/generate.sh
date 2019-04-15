#!/bin/sh

inventory_file_path=$1
pbench_label="pbench_role=agent"
register_all_nodes=$2
oc_client_url=$3
ansible_host=$4
prometheus_path=/root/svt/openshift_tooling/openshift_labeler/prometheus_metrics.yml
master_label="node-role.kubernetes.io/master"
etcd_label="node-role.kubernetes.io/master"
compute_label="node-role.kubernetes.io/worker"
infra_label="node-role.kubernetes.io/infra"
lb_label="node-role.kubernetes.io/lb"
gluster_label="node-role.kubernetes.io/cns"
pbench_node_count=2

# Check for kubeconfig
if [[ ! -s $HOME/.kube/config ]]; then
	echo "cannot find kube config in the home directory, please check"
	exit 1
fi

# Check if oc client is installed
echo "Checking if oc client is installed"
which oc &>/dev/null
if [[ $? != 0 ]]; then
	echo "oc client is not installed"
	echo "installing oc client"
 	curl -L $oc_client_url | tar -zx && \
    	mv openshift*/oc /usr/local/bin && \
	rm -rf openshift-origin-client-tools-*
else
	echo "oc client already present"
fi

if [[ -z $inv_path ]]; then
	inv_path="/root/tooling_inventory"
	echo "inventory path is not provided by the user, the inventory will be generated in the default location $inv_path"
fi

# delete tooling inventory if already exists
if [[ -f $inv_path ]]; then
        /bin/rm $inv_path
fi

# unlabel all nodes
oc label node --all pbench_role-

# generate inventory by looking at node labels
function generate_inventory() {
	group=$1
	label=$2
	echo "[$group]" >> $inv_path
	if [[ $group  == "pbench-controller" ]]; then
        	echo $ansible_host >> $inv_path
		echo -e "\n" >> $inv_path
	elif [[ $group == "pbench-controller:vars" ]]; then
		echo "register_all_nodes=$register_all_nodes" >> $inv_path		 
	else
        	for nodes in $(oc get nodes -l "$label" -o json | jq '.items[].metadata.name'); do
			if [[ $(oc get nodes -l $compute_label,$pbench_label | awk 'NR > 1 {print $1}' | wc -l) -ge $pbench_node_count ]]; then
				break
			fi
			node=$(echo $nodes |  sed "s/\"//g") 
			echo $node >> $inv_path
  			# label the node on which we want to run pbench-agent pods
			oc label node $node $pbench_label
        	done
		echo -e "\n" >> $inv_path
	fi
}

# generate inventory
# pbench-controller
generate_inventory pbench-controller

# master ( considers the case where master and etcd are co-located)
generate_inventory masters $master_label

# etcd ( considers the case where master and etcd are co-located)
generate_inventory etcd $etcd_label

# lb 
generate_inventory lb $lb_label

# infra
generate_inventory infra $infra_label

# cns
generate_inventory glusterfs $gluster_label

# nodes
generate_inventory nodes $compute_label

# prometheus-metrics
echo "[prometheus-metrics]" >> $inv_path
ansible-playbook -i $inv_path --extra-vars "inventory_file=$inv_path" $prometheus_path
if [[ $? != 0 ]]; then
	echo "Failed to prometheus-metrics hosts"
	exit 1
fi
echo -e "\n" >> $inv_path

# vars
generate_inventory pbench-controller:vars
