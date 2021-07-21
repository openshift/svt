#!/usr/bin/env python

import time
import yaml
import subprocess
import sys


# Invokes a given command and returns the stdout
def invoke(command):
    try:
        output = subprocess.check_output(command, shell=True,
                                         universal_newlines=True)
    except Exception as e:
        print("Failed to run %s" % (command))
        print("Error %s" % (str(e)))
        return ""
    return output


def set_max_unavailable(max_unavailable):

    merge_json ='{"spec":{"maxUnavailable":' + str(max_unavailable) + '}}'
    invoke("oc patch machineconfigpool.machineconfiguration.openshift.io/worker --type='merge' -p='"+ merge_json + "'")


def check_cluster_version():

    output = invoke("oc get clusterversion -o yaml")
    if output != "":
        #parse output to get cluster version and status?
        output = yaml.load(output, Loader=yaml.FullLoader)

        for condition in output['items'][0]['status']['conditions']:
            if "Progressing" == condition['type']:
                print("Progressing status " + str(condition['message']))
                break
        for status_history in output['items'][0]['status']['history']:
            if status_history['state'] == "Completed":
                print('actual version ' + str(status_history['version']))
                return status_history['version']
            else:
                print("State of version: " + str(status_history['state']) + " " + str(status_history['version']))
        print("\n\n")
        return output
    return ""

# Main function
def check_upgrade( expected_cluster_version):
    print("Starting upgrade check")
    upgrade_version = check_cluster_version()
    j = 0
    # Will wait for up to 2 hours.. might need to increase
    while j < 240:
        if upgrade_version == expected_cluster_version:
            wait_for_nodes_ready()
            wait_for_co_ready()
            return 0
        upgrade_version = check_cluster_version()
        time.sleep(30)
        j += 1
    return 1


def wait_for_co_ready():

    counter = 0
    wait_num = 30
    while counter < wait_num:
        count_not_ready = invoke("oc get co |sed '1d'|grep -v 'openshift-samples'|grep -v '.*True.*False.*False' | wc -l | xargs")
        if str(count_not_ready).strip() == "0":
            return
        print("Waiting 10 seconds for co to not be available")
        time.sleep(10)
        counter += 1
    print("ERROR: Co were still available and not progressing after 5 minutes")


def wait_for_nodes_ready():

    counter = 0
    wait_num = 60
    while counter < wait_num:
        count_not_ready = invoke("oc get nodes | grep 'NotReady\|SchedulingDisabled' | wc -l | xargs")
        print('count not ready ' +str(count_not_ready).strip())
        if str(count_not_ready).strip() == "0":
            return
        print("Waiting 30 seconds for nodes to become ready and scheduling enabled")
        time.sleep(30)
        counter += 1
    print("ERROR: Nodes were still not ready and scheduling enabled after 30 minutes")

def wait_for_replicas(machine_replicas, machine_name):
    counter = 0
    wait_num = 60
    replicas = invoke("oc get " + machine_name + " -n openshift-machine-api -o jsonpath={.status.availableReplicas}")
    while replicas != machine_replicas:
        time.sleep(5)
        replicas = invoke("oc get " + machine_name + " -n openshift-machine-api -o jsonpath={.status.availableReplicas}")
        print("Replicas didn't match, waiting 5 seconds")
        counter += 1
        if counter >= wait_num:
            print("ERROR, replica count doesn't match expected after 5 minutes")
            sys.exit(1)

    counter = 0
    not_ready_node = invoke("oc get nodes | grep 'NotReady' | wc -l | xargs")
    while int(not_ready_node) != 0:
        time.sleep(5)
        not_ready_node = invoke("oc get nodes | grep 'NotReady' | wc -l | xargs")
        print("Nodes not ready yet, waiting 5 seconds")
        counter += 1
        if counter >= wait_num:
            print("ERROR, nodes are still not ready after 5 minutes")
            sys.exit(1)
    print("Machine sets have correct replica count and all nodes are ready")

