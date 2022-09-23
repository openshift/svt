#!/usr/bin/env python

import subprocess
import time 
import sys

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

def wait_for_node_deletion(machine_set, wanted_replicas):
    machine_name = machine_set.split('/')[-1]
    cmd = "oc get machines -l machine.openshift.io/cluster-api-machineset=%s -n openshift-machine-api --no-headers| wc -l" % (machine_name)
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

def wait_for_node_creation(wanted_replicas, new_worker_instance_type):
    cmd = "oc get nodes -l node.kubernetes.io/instance-type=%s -n openshift-machine-api --no-headers | wc -l" % (new_worker_instance_type)
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

if(sys.argv[1]=='cluster_health_check'):
    cluster_health_check()