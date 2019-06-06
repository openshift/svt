#!/usr/bin/env python

from utils import *

#############################################################
# Test: Node Tuning Operator: core functionality is working #
#############################################################


def cleanup():
    print("Cleaning after test")
    execute_command("oc delete project my-logging-project")
    if execute_command("(ls default_values.yaml >> /dev/null 2>&1 && echo yes) || echo no").rstrip() == "yes":
        restore_default_values()


def restore_default_values():
    execute_command("oc delete tuned default")
    execute_command("oc create -f ./default_values.yaml")
    print("Waiting 15 seconds, to be sure changes has applied")
    countdown(15)


def count_log_applied_lines(list_of_pods, node_with_app):
    count = []
    for pod_in_list in list_of_pods:
        applied_profile = ""
        if pod_in_list['node'] == node_with_app and pod_in_list['role'] == "worker":
            applied_profile = "openshift-node-es"
        elif pod_in_list['node'] == node_with_app and pod_in_list['role'] == "master":
            applied_profile = "openshift-control-plane-es"
        elif pod_in_list['node'] != node_with_app and pod_in_list['role'] == "worker":
            applied_profile = "openshift-node"
        elif pod_in_list['node'] != node_with_app and pod_in_list['role'] == "master":
            applied_profile = "openshift-control-plane"
        count.append(int(execute_command("oc logs {} | grep -c \"\'{}\' applied\"".format(pod_in_list['pod'], applied_profile))))
    print(count)
    return count


# Test execution:
print_title("Node Tuning Operator: core functionality is working")


# Getting information about nodes and tuned pods.
print_step("Gathering information about nodes and tuned pods")
nodes = execute_command("oc get nodes --no-headers -o=custom-columns=NAME:.metadata.name").split("\n")
del nodes[-1]
tuned_pods = []
for node in nodes:
    tuned_pods.append(
        {
            'node': node,
            'role': execute_command("oc get node {} --no-headers | awk '{{print $3}}'".format(node)).rstrip(),
            'pod': execute_command("oc get pods -o wide -n openshift-cluster-node-tuning-operator | grep tuned | grep {} | awk '{{print $1}}'".format(node)).rstrip()
        }
    )
passed("List of nodes:\n" + str(tuned_pods))


# Verification if openshift-cluster-node-tuning-operator is running
print_step("Verification if openshift-cluster-node-tuning-operator is installed and running.")
execute_command("oc project openshift-cluster-node-tuning-operator")
number_of_deployments = execute_command("oc get deployment | grep -c cluster-node-tuning-operator")
print("Number of deployments: " + number_of_deployments)
if number_of_deployments == 0:
    fail("It looks like the openshift-cluster-node-tuning-operator is not running!", cleanup)


# Verification if all nodes are tuned
number_of_tuned_clusters = execute_command("oc get ds | grep tuned | tr -s ' ' | cut -d ' ' -f 2")
number_of_working_nodes = execute_command("oc get nodes | grep -c Ready")
print("Number of tuned clusters: {}".format(number_of_tuned_clusters))
print("Number of working nodes: {}".format(number_of_working_nodes))
if number_of_tuned_clusters != number_of_working_nodes:
    fail("Not all nodes are tuned!", cleanup)
passed(None)


# Verification number of secrets
print_step("Verification of number of secrets")
number_of_secrets = int(execute_command("oc get secrets -n openshift-cluster-node-tuning-operator | wc -l"))
if number_of_secrets > number_of_working_nodes * 3:
    fail("Number of secrets is too big: {}".format(number_of_secrets, cleanup))
passed(None)


# Verification that pod can be tuned
print_step("Verify that after creating new resource with 'es' label pod will be tuned")
execute_command("oc new-project my-logging-project")
execute_command("oc create -f https://raw.githubusercontent.com/hongkailiu/svt-case-doc/master/files/pod_test.yaml")
# Getting node where pod with 'web' name is running
node_where_app_is_running = execute_command("oc get pod web --no-headers -o=custom-columns=NODE:.spec.nodeName").rstrip()
# Verification node roles
node_type = execute_command("oc get node {} --no-headers | tr -s ' ' | cut -d ' ' -f 3".format(node_where_app_is_running)).rstrip()
profile = ""
if node_type == "worker":
    profile = "openshift-node-es"
elif node_type == "master":
    profile = "openshift-control-plane-es"

print ("Pod running on node: {} with role: {} - profile to verify: {}".format(node_where_app_is_running, node_type, profile))
execute_command("oc project openshift-cluster-node-tuning-operator")
tuned_pod = execute_command("oc get pods -o wide | grep tuned | grep {} | cut -d ' ' -f 1".format(node_where_app_is_running)).rstrip()
tuning_applied_for_label_before = int(execute_command("oc logs {} | grep -c \"\'{}\' applied\"".format(tuned_pod, profile)))
countdown(5)
execute_command("oc label pod web -n my-logging-project  tuned.openshift.io/elasticsearch=")
print("Waiting 120 seconds, to be sure changes has applied")
countdown(120)
tuning_applied_for_label_after = int(execute_command("oc logs {} | grep -c \"\'{}\' applied\"".format(tuned_pod, profile)))

print("\nResults:")
print("Pod\t\tBefore\tAfter")
print("{}\t{}\t{}".format(tuned_pod, tuning_applied_for_label_before, tuning_applied_for_label_after))
if tuning_applied_for_label_after > tuning_applied_for_label_before:
    passed(None)
else:
    fail("Pod {} should be tuned for {} profile.".format(tuned_pod, profile), cleanup)


# Verification that increasing net.netfilter.nf_conntrack_max will affect every node
print_step("Verify that modification (increase) of a parameter: net.netfilter.nf_conntrack_max will take effect on every node of the cluster.")
print("Checking logs of tuned pods on each node before test")
tuning_applied_before = count_log_applied_lines(tuned_pods, node_where_app_is_running)

conntract_max_before = int(execute_command("oc get tuned default -o yaml | grep \" net.netfilter.nf_conntrack_max\" | cut -d '=' -f 2"))
# Saving default configuration to file
print_step("Saving default configuration file")
execute_command("oc get tuned default -o yaml > default_values_netfilter.yaml")
execute_command("sed -e \"s/ net.netfilter.nf_conntrack_max={}/ net.netfilter.nf_conntrack_max={}/\" default_values_netfilter.yaml > new_conntract_increase.yaml".format(conntract_max_before, conntract_max_before + 1))
execute_command("oc apply -f new_conntract_increase.yaml")
print("Waiting 15 seconds, to be sure changes has applied")
countdown(15)
conntract_max_after = int(execute_command("oc get tuned default -o yaml | grep \" net.netfilter.nf_conntrack_max\" | cut -d '=' -f 2"))

for pod in tuned_pods:
    repeats = 0
    while True:
        conntract_max_on_node = int(execute_command_on_node(pod['node'], "sysctl net.netfilter.nf_conntrack_max").rstrip().split("=")[1])
        if conntract_max_after == conntract_max_on_node:
            print("Match on node: {} with value: {}".format(pod['node'], conntract_max_on_node))
            break
        repeats += 1
        countdown(10)
        if repeats > 12:
            fail("On node {} net.netfilter.nf_conntrack_max is {} instead {}".format(pod['node'], conntract_max_on_node, conntract_max_after), cleanup)

print("Checking logs of tuned pods on each node after test")
tuning_applied_after = count_log_applied_lines(tuned_pods, node_where_app_is_running)

print("\nResults:")
print("Pod\t\tBefore\tAfter")
for i in range(len(tuned_pods)):
    print("{}\t{}\t{}".format(tuned_pods[i]['pod'], tuning_applied_before[i], tuning_applied_after[i]))

for i in range(len(tuning_applied_before)):
    if tuning_applied_after[i] == tuning_applied_before[i]:
        fail("All pods should be tuned.", cleanup)
passed(None)


# Verification that decreasing net.netfilter.nf_conntrack_max will affect every node
print_step("Verify that modification (decrease) of a parameter: net.netfilter.nf_conntrack_max will take effect on every node of the cluster.")
print("Checking logs of tuned pods on each node before test")
tuning_applied_before = count_log_applied_lines(tuned_pods, node_where_app_is_running)

# Restoring previous value
conntract_max_before = int(execute_command("cat default_values_netfilter.yaml | grep \" net.netfilter.nf_conntrack_max\" | cut -d '=' -f 2"))
execute_command("oc get tuned default -o yaml > default_values_netfilter.yaml")
execute_command("sed -e \"s/ net.netfilter.nf_conntrack_max={}/ net.netfilter.nf_conntrack_max={}/\" default_values_netfilter.yaml > new_conntract_decrease.yaml".format(conntract_max_after, conntract_max_before))
execute_command("oc apply -f new_conntract_decrease.yaml")
print("Waiting 15 seconds, to be sure changes has applied")
countdown(15)
conntract_max_after = int(execute_command("oc get tuned default -o yaml | grep \" net.netfilter.nf_conntrack_max\" | cut -d '=' -f 2"))

for pod in tuned_pods:
    repeats = 0
    while True:
        conntract_max_on_node = int(execute_command_on_node(pod['node'], "sysctl net.netfilter.nf_conntrack_max").rstrip().split("=")[1])
        if conntract_max_after == conntract_max_on_node:
            print("Match on node: {} with value: {}".format(pod['node'], conntract_max_on_node))
            break
        repeats += 1
        countdown(10)
        if repeats > 12:
            fail("On node {} net.netfilter.nf_conntrack_max is {} instead {}".format(pod['node'], conntract_max_on_node, conntract_max_after), cleanup)

print("Checking logs of tuned pods on each node after test")
tuning_applied_after = count_log_applied_lines(tuned_pods, node_where_app_is_running)

print("\nResults:")
print("Pod\t\tBefore\tAfter")
for i in range(len(tuned_pods)):
    print("{}\t{}\t{}".format(tuned_pods[i]['pod'], tuning_applied_before[i], tuning_applied_after[i]))

for i in range(len(tuning_applied_before)):
    if tuning_applied_after[i] == tuning_applied_before[i]:
        fail("All pods should be tuned.", cleanup)
passed(None)


# Verification that increasing kernel.pid_max will affect every node
print_step("Verify that modification (increase) of a parameter: kernel.pid_max will take effect on every node of the cluster.")
print("Checking logs of tuned pods on each node before test")
tuning_applied_before = count_log_applied_lines(tuned_pods, node_where_app_is_running)

kernel_pid_max_before = int(execute_command_on_node(nodes[0], "sysctl kernel.pid_max").rstrip().split("=")[1])
default_kernel_pid = int(execute_command("oc get tuned default -o yaml | grep \" kernel.pid_max\" | cut -d '>' -f 2").rstrip())
execute_command("oc get tuned default -o yaml > default_values_pid.yaml")
execute_command("sed -e \"s/ kernel.pid_max=>{}/ kernel.pid_max=>{}/\" default_values_pid.yaml > new_kernel_pid_increase.yaml".format(default_kernel_pid, kernel_pid_max_before + 1))
execute_command("oc apply -f new_kernel_pid_increase.yaml")
print("Waiting 15 seconds, to be sure changes has applied")
countdown(15)
kernel_pid_max_after = int(execute_command("oc get tuned default -o yaml | grep \" kernel.pid_max\" | cut -d '>' -f 2").rstrip())

for pod in tuned_pods:
    repeats = 0
    while True:
        kernel_pid_max_on_node = int(execute_command_on_node(pod['node'], "sysctl kernel.pid_max").rstrip().split("=")[1])
        if kernel_pid_max_after == kernel_pid_max_on_node:
            print("Match on node: {} with value: {}".format(pod['node'], kernel_pid_max_on_node))
            break
        repeats += 1
        countdown(10)
        if repeats == 12:
            fail("On node {} kernel.pid_max is {} instead {}".format(pod['node'], kernel_pid_max_on_node, kernel_pid_max_after), cleanup)

print("Checking logs of tuned pods on each node after test")
tuning_applied_after = count_log_applied_lines(tuned_pods, node_where_app_is_running)
print("\nResults:")
print("Pod\t\tBefore\tAfter")
for i in range(len(tuned_pods)):
    print("{}\t{}\t{}".format(tuned_pods[i]['pod'], tuning_applied_before[i], tuning_applied_after[i]))

for i in range(len(tuning_applied_before)):
    if tuning_applied_after[i] == tuning_applied_before[i]:
        fail("All pods should be tuned.", cleanup)
passed(None)


# Verification that decreasing kernel.pid_max will affect every node
print_step("Verify that modification (decrease) of a parameter: kernel.pid_max will NOT take effect on every node of the cluster.")
print("Checking logs of tuned pods on each node before test")
tuning_applied_before = count_log_applied_lines(tuned_pods, node_where_app_is_running)

kernel_pid_max_before = int(execute_command_on_node(nodes[0], "sysctl kernel.pid_max").rstrip().split("=")[1])
execute_command("oc get tuned default -o yaml > default_values_pid.yaml")
execute_command("sed -e \"s/ kernel.pid_max=>{}/ kernel.pid_max=>{}/\" default_values_pid.yaml > new_kernel_pid_decrease.yaml".format(kernel_pid_max_before, default_kernel_pid))
execute_command("oc apply -f new_kernel_pid_decrease.yaml")
print("Waiting 15 seconds, to be sure changes has applied")
countdown(15)
kernel_pid_max_after = int(execute_command("oc get tuned default -o yaml | grep \" kernel.pid_max\" | cut -d '>' -f 2").rstrip())

repeats = 0
while True:
    print("Attempt #{}/12".format(repeats + 1))
    for pod in tuned_pods:
        kernel_pid_max_on_node = int(execute_command_on_node(pod['node'], "sysctl kernel.pid_max").rstrip().split("=")[1])
        if kernel_pid_max_before != kernel_pid_max_on_node:
            fail("On node {} kernel.pid_max is {} instead {}".format(pod['node'], kernel_pid_max_on_node, kernel_pid_max_after), cleanup)
        else:
            print("Match on node: {} with value: {}".format(pod['node'], kernel_pid_max_on_node))
    repeats += 1
    if repeats == 12:
        break
    print("Wait 10 seconds before next attempt")
    countdown(10)

print("Checking logs of tuned pods on each node after test")
tuning_applied_after = count_log_applied_lines(tuned_pods, node_where_app_is_running)

print("\nResults:")
print("Pod\t\tBefore\tAfter")
for i in range(len(tuned_pods)):
    print("{}\t{}\t{}".format(tuned_pods[i]['pod'], tuning_applied_before[i], tuning_applied_after[i]))

for i in range(len(tuning_applied_before)):
    if tuning_applied_after[i] == tuning_applied_before[i]:
        fail("All pods should be tuned.", cleanup)
passed(None)


# Verification that changing priority affect at least one node
print_step("Verify that after changing priority pod will be tuned")
print("Checking logs of tuned pods on each node before test")
tuning_applied_for_label_before = int(execute_command("oc logs {} | grep -c \"'openshift-node' applied\"".format(tuned_pod)))

# Saving default configuration to file
print_step("Saving default configuration file")
execute_command("oc get tuned default -o yaml > default_values_priority.yaml")
execute_command("sed -e \"s/ priority: 40/ priority: 15/\" default_values_priority.yaml > new_priority.yaml")
execute_command("oc apply -f new_priority.yaml")
print("Waiting 120 seconds, to be sure changes has applied")
countdown(120)
tuning_applied_for_label_after = int(execute_command("oc logs {} | grep -c \"'openshift-node' applied\"".format(tuned_pod)))

print("\nResults:")
print("Pod\t\tBefore\tAfter")
print("{}\t{}\t{}".format(tuned_pod, tuning_applied_for_label_before, tuning_applied_for_label_after))
if tuning_applied_for_label_after > tuning_applied_for_label_before:
    passed(None)
else:
    fail("Pod {} should be tuned.".format(tuned_pod), cleanup)


# Cleaning after tests when each step pass.
cleanup()
