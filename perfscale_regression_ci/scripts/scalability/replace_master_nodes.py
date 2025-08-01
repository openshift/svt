#!/usr/bin/env python

import sys
import os
import datetime
import utils.ocp_utils as ocp_utils
import time

# --- Helper function for this script (could be moved to ocp_utils.py) ---
def get_machine_name_from_node(node_name):
    """
    Gets the Machine object name associated with a given node name.
    Queries 'oc get machines' and parses output.
    Raises an exception if not found or multiple found.
    """
    cmd = f"oc get machines -n openshift-machine-api -o custom-columns=NAME:.metadata.name,NODE_NAME:.status.nodeRef.name --no-headers"
    output = ocp_utils.run(cmd)
    
    machine_name = None
    for line in output.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1] == node_name:
            if machine_name:
                raise ValueError(f"Found multiple Machine objects for node {node_name}. This is unexpected and indicates an issue.")
            machine_name = parts[0]
            
    if not machine_name:
        raise ValueError(f"No Machine object found for node {node_name} in openshift-machine-api namespace.")
    
    return machine_name

# FIRST CLUSTER HEALTH CHECK: Before executing the replacement loop
print("\n--- Initial Cluster Health Check ---")
ocp_utils.cluster_health_check()
print("--- Initial Cluster Health Check Complete ---\n")

n = len(sys.argv)
print(f"Total arguments passed: {n}")

cloud_type = sys.argv[1]
# This variable now represents the total number of masters we expect to have (e.g., 3)
num_masters_to_maintain = int(sys.argv[2]) 
new_master_instance_type = sys.argv[3]
NEW_MASTER_INSTANCE_TYPE="m5.4xlarge" # target instance size

# Define the name for the new machineset
cluster_name = os.environ.get('CLUSTER_NAME')
if not cluster_name:
    print("Error: CLUSTER_NAME environment variable not set. Please set it before running.")
    sys.exit(1)
    
new_machineset_name = cluster_name + "-master-new"
final_machine_set_path = "machinesets/" + new_machineset_name

print(f"Preparing to replace master nodes. Target new instance type: {new_master_instance_type}")
print(f"New machineset for replacement masters: {final_machine_set_path}")
print(f"Total master nodes to maintain in the cluster: {num_masters_to_maintain}")

# --- Phase 1: Prepare the New Machineset and ensure it's at 0 replicas ---
print(f"Applying new machineset definition for {new_machineset_name}...")
# Note: NEW_MASTER_INSTANCE_TYPE needs to be an environment variable for envsubst
os.environ['NEW_MASTER_INSTANCE_TYPE'] = new_master_instance_type
ocp_utils.run(f"envsubst < ./replace_nodes/clouds/master-node-machineset-{cloud_type}.yaml | oc apply -f -")

current_new_replicas_raw = ocp_utils.get_machine_replicas(final_machine_set_path)
current_new_replicas = 0 # Default value

if current_new_replicas_raw is not None and current_new_replicas_raw != '':
    try:
        current_new_replicas = int(current_new_replicas_raw)
    except ValueError:
        # This case should ideally be rare if the above check is thorough,
        # but it catches other non-numeric strings if any.
        print(f"Warning: Could not convert replicas '{current_new_replicas_raw}' to an integer. Assuming 0.")
else:
    # This block handles None or empty string, setting replicas to 0.
    # We can add an informational message here instead of a warning.
    print(f"Info: Machineset {final_machine_set_path} replica count initially unavailable or empty. Assuming 0 replicas.")

if current_new_replicas > 0:
    print(f"New machineset {final_machine_set_path} unexpectedly has {current_new_replicas} replicas. Scaling down to 0 to prepare for one-by-one replacement.")
    ocp_utils.scale_machine_replicas(final_machine_set_path, 0)
    print("Waiting for any existing machines from new machineset to be removed...")
    time.sleep(30)
    current_new_replicas = 0
print(f"New machineset {final_machine_set_path} initialized with {current_new_replicas} replicas.")

# --- Phase 2: One-by-One Replacement Loop ---
# Identify the current 'old' master nodes by their role.
old_master_node_names = ocp_utils.run("oc get nodes -l node-role.kubernetes.io/master --no-headers -o name").strip().split('\n')
old_master_node_names = [name.split('/')[1].strip() for name in old_master_node_names if name.strip()]

if not old_master_node_names:
    print("Error: No existing master nodes with 'control-plane,master' role found. Cannot proceed with replacement.")
    sys.exit(1)

# Sort for predictable order, especially useful in CI/debugging
old_master_node_names.sort() 

print(f"Identified {len(old_master_node_names)} existing old master nodes for replacement: {old_master_node_names}")

if len(old_master_node_names) != num_masters_to_maintain:
    print(f"Warning: Number of identified old masters ({len(old_master_node_names)}) does not match expected target ({num_masters_to_maintain}). Proceeding with {len(old_master_node_names)} nodes.")
    num_masters_to_maintain = len(old_master_node_names)

print(f"Starting one-by-one master node replacement for {num_masters_to_maintain} nodes.")

# This loop ensures we replace exactly 'num_masters_to_maintain' masters.
# We will iterate for each master to be replaced.
# We take one old master, replace it with one new master, and repeat.
for i in range(num_masters_to_maintain):
    print(f"\n--- Replacement Iteration {i+1} of {num_masters_to_maintain} ---")

    # Ensure we have an old master node to replace
    if not old_master_node_names:
        print("Warning: No more old master nodes to decommission, but more iterations expected. Exiting loop.")
        break
        
    old_node_to_decommission = old_master_node_names.pop(0) # Get and remove the first old node
    print(f"Selected old master node for decommissioning: {old_node_to_decommission}")

    try:
        # 1. Scale up the new machineset by 1
        # This brings up a new master machine with the desired instance type.
        new_replica_count_for_new_machineset = i + 1 # Target 1, then 2, then 3 replicas in the new machineset
        print(f'Start time: Scaling up new machineset {new_machineset_name} to {new_replica_count_for_new_machineset} replicas at ' + str(datetime.datetime.now()))
        ocp_utils.scale_machine_replicas(final_machine_set_path, new_replica_count_for_new_machineset)
        
        # Wait for the *new* master node to be created and become Ready
        print(f"Waiting for new master node (from {new_machineset_name}) to become Ready. Total new masters expected: {new_replica_count_for_new_machineset}...")
        # ocp_utils.wait_for_master_node_creation needs to be robust:
        # It should count 'Ready' masters with 'control-plane,master' role and potentially filter by new instance type.
        # This is critical to ensure the new node is fully functional before decommissioning an old one.
        ocp_utils.wait_for_master_node_creation(new_replica_count_for_new_machineset, new_master_instance_type) 
        print(f'End time: New master node from {new_machineset_name} is ready at ' + str(datetime.datetime.now()))

        # 2. Decommission the old master node
        print(f"Proceeding to decommission old master node: {old_node_to_decommission}")
        old_machine_name = get_machine_name_from_node(old_node_to_decommission)
        print(f"Found Machine {old_machine_name} for node {old_node_to_decommission}.")

        # Cordon the old node
        print(f"Cordoning node {old_node_to_decommission}...")
        ocp_utils.run(f"oc adm cordon {old_node_to_decommission}")

        # Drain the old node
        print(f"Draining node {old_node_to_decommission}...")
        # Use --force and --delete-emptydir-data for robustness in CI environments
        ocp_utils.run(f"oc adm drain {old_node_to_decommission} --force --delete-emptydir-data --ignore-daemonsets --skip-waitForDeleteTimeout")

        # Delete the old Machine object
        print(f"Deleting Machine {old_machine_name} in namespace openshift-machine-api...")
        ocp_utils.run(f"oc delete machine {old_machine_name} -n openshift-machine-api")

        # Wait for the old node to disappear from 'oc get nodes'
        print(f"Waiting for node {old_node_to_decommission} to disappear...")
        ocp_utils.wait_for_master_node_deletion(old_node_to_decommission) 
        print(f"Node {old_node_to_decommission} and Machine {old_machine_name} successfully deleted.")

    except Exception as e:
        print(f"Error during decommissioning of old master node {old_node_to_decommission}: {e}")
        print("This is a critical error during master replacement. Aborting.")
        sys.exit(1)
    
# --- FINAL CLUSTER HEALTH CHECK: After all replacements are complete ---
print("\n--- Master node replacement process completed ---")
print("--- Final Cluster Health Check ---")
ocp_utils.cluster_health_check()
print("--- Final Cluster Health Check Complete ---")