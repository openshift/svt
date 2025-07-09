#!/usr/bin/env python

import subprocess
import time 
import sys
import json

def run(command, print_out=False):
    try:
        #print (command)
        output = subprocess.Popen(command, shell=True,
                                    universal_newlines=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT)
        (out, err) = output.communicate()
        if (print_out == True):
            print (command)
            print(str(out))
    except Exception as e:
        print("Failed to run %s, error: %s" % (command, e))
    return out.strip()

def get_machine_replicas(machine_set):
    print('machine_set ' + str(machine_set))
    cmd = "oc get %s -o jsonpath='{.status.replicas}' -n openshift-machine-api" % (machine_set)
    while True:
        try:
            replicas=run(cmd)
            print("%s replicas %s \n" % (machine_set, str(replicas)))
            print ()
        except ValueError as err:
            print (err)
            continue
        else:
            break
    return replicas

def scale_machine_replicas(machine_set, replicas):
    cmd = "oc scale %s -n openshift-machine-api --replicas=%s" % (machine_set, str(replicas))
    while True:
        try:
            run(cmd, True)
        except ValueError as err:
            print (err)
            continue
        else:
            break

def wait_for_worker_node_deletion(machine_set, wanted_replicas):
    machine_name = machine_set.split('/')[-1]
    cmd = "oc get machines -l machine.openshift.io/cluster-api-machineset=%s -n openshift-machine-api --no-headers | grep worker | wc -l" % (machine_name)
    while True:
        try:
            replicas=run(cmd)
            if "No resources found" in replicas:
                print("No resources found")
                return
        except ValueError as err:
            print (err)
            continue
        else:
            break
    while int(wanted_replicas) != int(replicas):
        print('wanted vs. actual replicas ' + str(wanted_replicas) +" " + str(replicas))
        time.sleep(5)
        try:
            replicas=run(cmd)
        except ValueError as err:
            print (err)
            continue
        if "No resources found" in replicas:
            print("No resources found")
            break
    print()

def wait_for_worker_node_creation(wanted_replicas, new_worker_instance_type):
    cmd = "oc get nodes -l node.kubernetes.io/instance-type=%s -n openshift-machine-api --no-headers | grep worker | wc -l" % (new_worker_instance_type)
    while True:
        try:
            replicas=run(cmd)
        except ValueError as err:
            print (err)
            continue
        else:
            if "No resources found" in replicas:
                continue
            else:
                break
    while int(wanted_replicas) != int(replicas):
        print('wanted vs. actual replicas ' + str(wanted_replicas) +" " + str(replicas))
        time.sleep(5)
        try:
            replicas=run(cmd)
        except ValueError as err:
            print (err)
            continue
        if "No resources found" in replicas:
            print ("No resources found")
            continue
    print()

def wait_for_master_node_deletion(machine_set, wanted_replicas):
    machine_name = machine_set.split('/')[-1]
    cmd = "oc get machines -l machine.openshift.io/cluster-api-machineset=%s -n openshift-machine-api --no-headers | grep control-plane,master | wc -l" % (machine_name)
    while True:
        try:
            replicas=run(cmd)
            if "No resources found" in replicas:
                print("No resources found")
                return
        except ValueError as err:
            print (err)
            continue
        else:
            break
    while int(wanted_replicas) != int(replicas):
        print('wanted vs. actual replicas ' + str(wanted_replicas) +" " + str(replicas))
        time.sleep(5)
        try:
            replicas=run(cmd)
        except ValueError as err:
            print (err)
            continue
        if "No resources found" in replicas:
            print("No resources found")
            break
    print()

def wait_for_master_node_creation(wanted_replicas, new_master_instance_type):
    cmd = "oc get nodes -l node.kubernetes.io/instance-type=%s -n openshift-machine-api --no-headers | grep control-plane,master | wc -l" % (new_master_instance_type)
    while True:
        try:
            replicas=run(cmd)
        except ValueError as err:
            print (err)
            continue
        else:
            if "No resources found" in replicas:
                continue
            else:
                break
    while int(wanted_replicas) != int(replicas):
        print('wanted vs. actual replicas ' + str(wanted_replicas) +" " + str(replicas))
        time.sleep(5)
        try:
            replicas=run(cmd)
        except ValueError as err:
            print (err)
            continue
        if "No resources found" in replicas:
            print ("No resources found")
            continue
    print()

def delete_machineset(machineset):
    cmd = "oc delete %s -n openshift-machine-api" % (machineset)
    while True:
        try:
            run(cmd)
        except ValueError as err:
            print (err)
        else:
            break
    time.sleep(2)

def cluster_health_check():
    print("Basic cluster health check.")
    while True:
        try:
            run("oc get nodes",True)
            run("oc get co --no-headers| grep -v 'True.*False.*False'",True)
            run("oc get pods --no-headers -A| egrep -v 'Running|Completed'",True)
        except ValueError as err:
            print (err)
        else:
            break

def update_master_machineset(master_machineset_name, new_master_instance_type):
    """
    Updates the instanceType of the specified master machineset.
    :param machineset_name: The name of the master machineset (e.g., "cluster-name-master").
    :param new_instance_type: The new instance type to set (e.g., "m5.4xlarge").
    """
    # Construct the JSON patch payload
    patch_payload = {
        "spec": {
            "template": {
                "spec": {
                    "providerSpec": {
                        "value": {
                            "instanceType": new_master_instance_type
                        }
                    }
                }
            }
        }
    }
    
    # Convert payload to a JSON string
    patch_json = json.dumps(patch_payload)
    
    # Construct the oc patch command
    # Use --type=merge for simplicity, or --type=json --patch='[{"op": "replace", "path": "/spec/template/spec/providerSpec/value/instanceType", "value": "new_type"}]'
    # The merge strategy is often easier for simple field updates.
    cmd = f"oc patch machineset {master_machineset_name} -n openshift-machine-api --type=merge -p '{patch_json}'"
    
    try:
        run(cmd)
        print(f"Successfully patched machineset {master_machineset_name} with new instance type {new_master_instance_type}.")
    except Exception as e:
        print(f"Failed to patch machineset {master_machineset_name}: {e}")
        raise

def get_machine_name_from_node(node_name):
    """
    Gets the Machine object name associated with a given node name.
    """
    cmd = f"oc get machines -n openshift-machine-api -o custom-columns=NAME:.metadata.name,NODE_NAME:.status.nodeRef.name --no-headers"
    output = run(cmd)
    
    machine_name = None
    for line in output.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1] == node_name:
            if machine_name:
                raise ValueError(f"Found multiple Machine objects for node {node_name}. This is unexpected.")
            machine_name = parts[0]
            
    if not machine_name:
        raise ValueError(f"No Machine object found for node {node_name} in openshift-machine-api namespace.")
    
    return machine_name
