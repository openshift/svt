#!/usr/bin/env python

import sys
import os
import datetime
import utils.ocp_utils as ocp_utils
import time

n = len(sys.argv)
print(f"Total arguments passed: {n}")

cloud_type = sys.argv[1]
num_masters_to_maintain = int(sys.argv[2]) 
new_master_instance_type = "m5.4xlarge"

cluster_name = os.environ.get('CLUSTER_NAME')
if not cluster_name:
    print("Error: CLUSTER_NAME environment variable not set. Please set it before running.")
    sys.exit(1)

master_machineset_name = f"{cluster_name}-master"

print(f"Preparing to upgrade master nodes to instance type: {new_master_instance_type}")
print(f"Targeting existing master machineset: {master_machineset_name}")

# --- Phase 1: Update the Existing Master MachineSet Template ---
print(f"\n--- Phase 1: Updating Machineset Template ---")
print(f"Updating instance type of master machineset {master_machineset_name} to {new_master_instance_type}...")
ocp_utils.update_master_machineset(master_machineset_name, new_master_instance_type)
print(f"Master machineset {master_machineset_name} template updated.")

# --- Phase 2: One-by-One Rolling Replacement ---
print(f"\n--- Phase 2: Starting Rolling Replacement ---")
old_master_node_names = ocp_utils.run("oc get nodes -l node-role.kubernetes.io/master --no-headers -o name").strip().split('\n')
old_master_node_names = [name.split('/')[1].strip() for name in old_master_node_names if name.strip()]

if len(old_master_node_names) != num_masters_to_maintain:
    print(f"Error: Expected {num_masters_to_maintain} masters to replace, but found {len(old_master_node_names)}. Please ensure the cluster is in a stable state before proceeding.")
    sys.exit(1)

old_master_node_names.sort() 
print(f"Identified {len(old_master_node_names)} existing master nodes for replacement: {old_master_node_names}")

print(f"Starting one-by-one rolling replacement for {num_masters_to_maintain} nodes.")

for i, old_node_to_decommission in enumerate(old_master_node_names):
    print(f"\n--- Replacement Iteration {i+1} of {num_masters_to_maintain} ---")
    print(f"Selected master node for upgrade: {old_node_to_decommission}")

    try:
        # Step 1: Cordon the old node
        print(f"Cordoning node {old_node_to_decommission}...")
        ocp_utils.run(f"oc adm cordon {old_node_to_decommission}")

        # Step 2: Get the Machine object name for this node
        old_machine_name = ocp_utils.get_machine_name_from_node(old_node_to_decommission)
        print(f"Found Machine {old_machine_name} for node {old_node_to_decommission}.")

        # Step 3: Delete the Machine object to trigger a replacement
        print(f"Deleting Machine {old_machine_name} in namespace openshift-machine-api to trigger replacement...")
        ocp_utils.run(f"oc delete machine {old_machine_name} -n openshift-machine-api")

        # Step 4: Wait for a new master node to appear and become ready
        # The machineset controller will provision a new machine with the updated instance size.
        print(f"Waiting for new master node to appear with instance type {new_master_instance_type} and become Ready...")
        # This function should wait for the total number of masters to return to 'num_masters_to_maintain'
        # with the correct instance type.
        ocp_utils.wait_for_master_node_creation(num_masters_to_maintain, new_master_instance_type) 

        # Step 5: Uncordon the node once the new instance is ready
        # The new instance will have the same hostname/node name, so we uncordon that name.
        print(f"New instance is Ready. Uncordoning node {old_node_to_decommission}...")
        ocp_utils.run(f"oc adm uncordon {old_node_to_decommission}")
        
        print(f"Node {old_node_to_decommission} successfully upgraded to instance type {new_master_instance_type}.")

    except Exception as e:
        print(f"Error during upgrade of master node {old_node_to_decommission}: {e}")
        print("This is a critical error during master replacement. Aborting.")
        sys.exit(1)

print("\n--- Final Master Node Upgrade Completed ---")
ocp_utils.cluster_health_check()
print("--- Final Cluster Health Check Complete ---")
