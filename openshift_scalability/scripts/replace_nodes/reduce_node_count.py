replace_nodes/reduce_node_count.pyimport subprocess
import time 
import sys
import os


def run(command):
    try:
        output = subprocess.Popen(command, shell=True,
                                    universal_newlines=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT)
        (out, err) = output.communicate()
        print('out ' + str(out))
    except Exception as e:
        print("Failed to run %s, error: %s" % (command, e))
    return out.strip()

def get_machine_replicas(machine_set):
    print('machine_set ' + str(machine_set)) 
    replicas=run("oc get %s -o jsonpath='{.status.replicas}' -n openshift-machine-api" % (machine_set))
    print("%s replicas %s" % (machine_set, str(replicas)))
    return replicas

def scale_down_machine_replicas(machine_set, replicas):

    run("oc scale %s -n openshift-machine-api --replicas=%s" % (machine_set, str(replicas)))
    wait_for_node_deletion(machine_set, replicas)


def wait_for_node_deletion(machine_set, wanted_replicas): 
    machine_name = machine_set.split('/')[-1]
    cmd = "oc get machines -l machine.openshift.io/cluster-api-machineset=%s -n openshift-machine-api --no-headers| wc -l" % (machine_name)
    replicas=run(cmd)
    if "No resources found" in replicas:
        return
    while int(wanted_replicas) != int(replicas):
        print('wanted vs. actual replicas ' + str(wanted_replicas) +" " + str(replicas))
        time.sleep(5)
        replicas=run(cmd)
        if "No resources found" in replicas:
            break

    
def wait_for_node_creation(machine_set, wanted_replicas): 
    machine_name = machine_set.split('/')[-1]
    cmd = "oc get nodes -n openshift-machine-api --no-headers| grep %s | wc -l" % (machine_name)
    replicas=run(cmd)
    if "No resources found" in replicas:
        return
    while int(wanted_replicas) != int(replicas):
        print('wanted vs. actual replicas ' + str(wanted_replicas) +" " + str(replicas))
        time.sleep(5)
        replicas=run(cmd)
        if "No resources found" in replicas:
            break

# total arguments
n = len(sys.argv)
print("Total arguments passed:", n)

cloud_type=sys.argv[1]

run("envsubst < clouds/worker-node-machineset-%s.yaml | oc apply -f -" % cloud_type)

final_machine_set="machinesets/"+os.environ['CLUSTER_NAME'] + "-worker-new"

wait_for_node_creation(final_machine_set, 15)
machines_sets=run("oc get machinesets -A -o name  --no-headers").split('\n')
print('machine sets ' + str(machines_sets))
for machineset in machines_sets:
    final_machine_set_name = final_machine_set.split('/')[-1]
    print('final name' + str(final_machine_set_name))
    if final_machine_set_name in machineset: 
        continue

    replicas = get_machine_replicas(machineset)
    if "No resources found" in replicas:
        continue
    while int(replicas) >= 0: 
        replicas = int(replicas) - 1
        scale_down_machine_replicas(machineset, replicas)

run("kubectl top nodes")