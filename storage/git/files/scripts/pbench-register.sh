#!/bin/bash

pbench-kill-tools
pbench-clear-tools
pbench-clear-results

echo "jump_node: ${jump_node}"

if [[ ! -z "$1" ]] && [[ $(echo "$1" | awk '{print tolower($0)}') = "true" ]]; then
  pbench-register-tool-set --label="jump_node"
fi


function get_pbench_label {
  local role
  role=$(oc get node $1 --no-headers | awk '{print $3}')

  local glusterfs_storage_nodes
  glusterfs_storage_nodes=($(oc get pod -n glusterfs -o wide | grep glusterfs-storage | awk '{print $7}'))
  for glusterfs_storage_node in "${glusterfs_storage_nodes[@]}"
  do
    if [[ "${1}" = "${glusterfs_storage_node}" ]]; then
      role=${role},glusterfs_storage
    fi
  done

  local heketi_nodes
  heketi_nodes=($(oc get pod -n glusterfs -o wide | grep heketi | awk '{print $7}'))
  for heketi_node in "${heketi_nodes[@]}"
  do
    if [[ "${1}" = "${heketi_node}" ]]; then
      role=${role},heketi
    fi
  done

  local glusterblock_storage_provisioner_nodes
  glusterblock_storage_provisioner_nodes=($(oc get pod -n glusterfs -o wide | grep glusterblock-storage-provisioner | awk '{print $7}'))
  for glusterblock_storage_provisioner_node in "${glusterblock_storage_provisioner_nodes[@]}"
  do
    if [ "${1}" = "${glusterblock_storage_provisioner_node}" ]; then
      role=${role},glusterblock_storage_provisioner
    fi
  done
  echo "${role}"
}

NODES=($(oc get node  --no-headers | awk '{print $1}'))
for node in "${NODES[@]}"
do
  label=$(get_pbench_label ${node})
  pbench-register-tool-set --label="${label}" --remote="${node}"
  if [[ ${label} = *"master"* ]]; then
    pbench-register-tool --name=oc --label="${label}" --remote="${node}"
  fi
done