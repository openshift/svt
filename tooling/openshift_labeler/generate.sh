#!/bin/sh

file=$1
hosts=/run/openshift/label.tmp.hosts
inventory_file_path=$2
label_prefix="node_role"
pbench_label="pbench_role=agent"
inv_path=$3
register_all_nodes=$4
oc_client_url=$5
declare -a host
declare -a group
declare -a label

# Check for kubeconfig
if [[ ! -s $HOME/.kube/config ]]; then
	echo "cannot find kube config in the home directory, please check"
	exit 1
fi

# Check if oc client is installed
which oc &>/dev/null
echo "Checking if oc client is installed"
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

function cleanup() {
	/bin/rm $file
	/bin/rm $hosts
}

# generate inventory by looking at node labels
function generate_inventory() {
	group=$1
	node_label=$2
	second_label=$3
	echo "[$group]" >> $inv_path
	if [[ $group  == "pbench-controller" ]]; then
        	echo $(hostname) >> $inv_path
		echo -e "\n" >> $inv_path
	elif [[ $group == "pbench-controller:vars" ]]; then
		echo "register_all_nodes=$register_all_nodes" >> $inv_path		 
	else
        	for nodes in $(oc get nodes -l role=$node_label -o json | jq '.items[].metadata.name'); do
                	echo $nodes |  sed "s/\"//g" >> $inv_path
        	done
		if [[ ! -z $second_label ]]; then
			for nodes in $(oc get nodes -l role=$second_label -o json | jq '.items[].metadata.name'); do
                                echo $nodes |  sed "s/\"//g" >> $inv_path
                        done
		fi
		echo -e "\n" >> $inv_path
	fi
}

while read -u 9 line;do
  hostname=$(echo $line | awk -F' ' '{print $1}')
  group_name=$(echo $line | awk -F' ' '{print $2}')
  label_name="$group_name"
  host[${#host[@]}]=$hostname
  group[${#group[@]}]=$group_name
  label[${#label[@]}]=$label_name
done 9< $file
array_length=${#host[*]}
for ((i=0; i<$array_length; i++));do
  for ((j=i+1; j<$array_length; j++));do
    if [[ ${host[i]} == ${host[j]} ]] && [[ ${host[i]} != '' ]]; then
      label[i]=$(echo ${label[i]}_${group[j]})
      unset label[j]
      unset host[j]
      unset group[j]
    fi
  done
  if [[ ${host[i]} != '' ]]; then
    echo ${host[i]} ${group[i]} ${label[i]} >> $hosts
  fi
done
while read -u 11 line;do
  host=$(echo $line | awk -F' ' '{print $1}')
  group=$(echo $line | awk -F' ' '{print $2}')
  label=$(echo $line | awk -F' ' '{print $3}')
  # unlabel the node in case it's already labeled
  oc label node $host $label_prefix-
  oc label node $host $label_prefix"="$label
  # label the node on which we want to run pbench-agent pods
  oc label node $host $pbench_label
done 11< $hosts

# generate inventory
# pbench-controller
generate_inventory pbench-controller

# master ( considers the case where master and etcd are co-located)
generate_inventory masters master master_etcd

# nodes
generate_inventory nodes node

# etcd (considers the case where master and etcd are co-lacated)
generate_inventory etcd etcd master_etcd

# lb 
generate_inventory lb lb

# cns
generate_inventory glusterfs cns

# prometheus-metrics
echo "[prometheus-metrics]" >> $inv_path
ansible-playbook -i $inv_path /root/openshift-labeler/prometheus_metrics.yml 
echo -e "\n" >> $inv_path

# vars
generate_inventory pbench-controller:vars

# cleanup
cleanup
