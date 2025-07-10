#!/usr/bin/env python

import sys
import os
import datetime
import utils.ocp_utils as ocp_utils

# Perform a basic cluster health check before starting
ocp_utils.cluster_health_check()

n = len(sys.argv)
print(f"Total arguments passed: {n}")

cloud_type = sys.argv[1]
# 'target_master_replicas' represents the total number of master nodes we aim to have
# from the *new* machineset, which implicitly means we will replace that many old masters.
target_master_replicas = int(sys.argv[2]) # Convert to int for calculations
new_master_instance_type = sys.argv[3]

# Define the name for the new machineset
new_machineset_name = os.environ['CLUSTER_NAME'] + "-master-new"
final_machine_set_path = "machinesets/" + new_machineset_name

print(f"Targeting {target_master_replicas} master replicas with new machineset: {final_machine_set_path}")

# --- Phase 1: Prepare the New Machineset ---
# 1. Apply the new machineset definition. It will be created but initially scaled to 0 replicas.
# This ensures the machineset exists before we try to scale it up incrementally.
print(f"Applying new machineset definition for {new_machineset_name}...")
ocp_utils.run(f"envsubst < ./replace_nodes/clouds/master-node-machineset-{cloud_type}.yaml | oc apply -f -")

# 2. Ensure the new machineset starts with 0 replicas.
# This is crucial for the one-by-one scaling.
current_new_replicas = ocp_utils.get_machine_replicas(final_machine_set_path)
if current_new_replicas is None or current_new_replicas > 0:
    print(f"New machineset {final_machine_set_path} currently has {current_new_replicas} replicas. Scaling down to 0 to prepare for one-by-one replacement.")
    ocp_utils.scale_machine_replicas(final_machine_set_path, 0)
    ocp_utils.wait_for_master_node_deletion(final_machine_set_path, 0)
    current_new_replicas = 0
print(f"New machineset {final_machine_set_path} initialized with {current_new_replicas} replicas.")


# --- Phase 2: Identify Existing Master Machinesets ---
# Get all machinesets and filter for original master ones (excluding the new one and infra)
all_machinesets_names = ocp_utils.run("oc get machinesets -A -o name --no-headers").split('\n')
original_master_machinesets_info = []
total_current_old_masters = 0

for ms_name in all_machinesets_names:
    ms_name = ms_name.strip()
    if not ms_name:
        continue
    # Skip the new machineset and infra machinesets
    if new_machineset_name in ms_name or "infra" in ms_name:
        continue

    try:
        replicas_count = int(ocp_utils.get_machine_replicas(ms_name))
        if replicas_count > 0:
            original_master_machinesets_info.append({"name": ms_name, "current_replicas": replicas_count})
            total_current_old_masters += replicas_count
    except Exception as e:
        print(f"Warning: Could not get replicas for machineset {ms_name}: {e}. Skipping.")
        continue

if not original_master_machinesets_info:
    print("Error: No existing master machinesets with active replicas found to replace. Exiting.")
    sys.exit(1)

print(f"Identified existing master machinesets for replacement: {original_master_machinesets_info}")
print(f"Total current old masters to replace: {total_current_old_masters}")

# Determine the number of replacement cycles needed.
# This should match the total number of old masters found.
num_replacement_cycles = total_current_old_masters

if num_replacement_cycles == 0:
    print("No old master nodes found to replace. Exiting.")
    sys.exit(0)

# --- Phase 3: One-by-One Replacement Loop ---
for i in range(num_replacement_cycles):
    print(f"\n--- Replacement Iteration {i+1} of {num_replacement_cycles} ---")

    # 1. Scale up the new machineset by 1
    print(f'Start time: Scaling up new machineset {new_machineset_name} by 1 at ' + str(datetime.datetime.now()))
    current_new_replicas += 1
    ocp_utils.scale_machine_replicas(final_machine_set_path, current_new_replicas)
    # Wait for the total number of new masters to be ready
    ocp_utils.wait_for_master_node_creation(current_new_replicas, new_master_instance_type)
    print(f'End time: Finished scaling up {new_machineset_name} to {current_new_replicas} replicas at ' + str(datetime.datetime.now()))
    ocp_utils.cluster_health_check() # Perform health check after adding a new node

    # 2. Identify an old machineset with active replicas and scale it down by 1
    old_machineset_to_decrement = None
    for ms_info in original_master_machinesets_info:
        if ms_info["current_replicas"] > 0:
            old_machineset_to_decrement = ms_info
            break

    if old_machineset_to_decrement is None:
        print("Warning: No more old master machinesets found with replicas to scale down. This might indicate an issue or that more new masters were targeted than old ones existed.")
        break # Exit loop if no more old masters can be found

    old_ms_name = old_machineset_to_decrement["name"]
    old_machineset_to_decrement["current_replicas"] -= 1 # Update our internal tracking
    new_old_replicas_count = old_machineset_to_decrement["current_replicas"]

    print(f'Start time: Scaling down old machineset {old_ms_name} to {new_old_replicas_count} at ' + str(datetime.datetime.now()))
    ocp_utils.scale_machine_replicas(old_ms_name, new_old_replicas_count)
    # Wait for the old machineset to reach its new, reduced replica count
    ocp_utils.wait_for_master_node_deletion(old_ms_name, new_old_replicas_count)
    print(f'End time: Finished scaling down {old_ms_name} to {new_old_replicas_count} replicas at ' + str(datetime.datetime.now()))
    ocp_utils.cluster_health_check() # Perform health check after deleting an old node

print("\n--- Master node replacement process completed ---")
print("Final cluster health check:")
ocp_utils.cluster_health_check()

# The original script commented out the 'delete_machineset' call after scaling down.
# This revised script maintains that behavior, so old machinesets are scaled down to 0 but not explicitly deleted.
