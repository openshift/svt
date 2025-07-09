#!/usr/bin/env python

import sys
import os
import datetime
import utils.ocp_utils as ocp_utils

# basic cluster health check prior to replacing nodes
ocp_utils.cluster_health_check()

# total arguments
n = len(sys.argv)
print("Total arguments passed:", n)

cloud_type=sys.argv[1]
replicas=sys.argv[2]
new_worker_instance_type=sys.argv[3]

ocp_utils.run("envsubst < ./replace_nodes/clouds/worker-node-machineset-%s.yaml | oc apply -f -" % cloud_type)

final_machine_set="machinesets/"+os.environ['CLUSTER_NAME'] + "-worker-new"

print('Start time: Scaling up new machineset {} at '.format(final_machine_set) + str(datetime.datetime.now()))
ocp_utils.scale_machine_replicas(final_machine_set, replicas)
ocp_utils.wait_for_worker_node_creation(replicas, new_worker_instance_type)
print('End time: Finished scaling up {} at '.format(final_machine_set) + str(datetime.datetime.now()))

machines_sets=ocp_utils.run("oc get machinesets -A -o name  --no-headers").split('\n')
print('machine sets \n' + str(machines_sets))


for machineset in machines_sets:
    final_machine_set_name = final_machine_set.split('/')[-1]
    if final_machine_set_name in machineset: 
        print ("new machine set in use \n")
        continue
    if "infra" in machineset: 
        print ("skip infra machineset \n")
        continue
    else:
        replicas = ocp_utils.get_machine_replicas(machineset)
        #print (replicas)
        if "No resources found" in replicas:
            continue
        # delete old machines 
        print('Start time: Deleting nodes from {} at '.format(machineset) + str(datetime.datetime.now()))
        while int(replicas) >= 1: 
            replicas = int(replicas) - 1
            ocp_utils.scale_machine_replicas(machineset, replicas) 
            ocp_utils.wait_for_worker_node_deletion(machineset, replicas)
        print('End time: All nodes deleted from {} at '.format(machineset) + str(datetime.datetime.now()))
        print()
        ocp_utils.cluster_health_check()
        #delete_machineset(machineset) #After scaling down do not delete machinesets for this scenario
