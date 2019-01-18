#!/usr/bin/env python

import subprocess
import time

#############################################################
# Test: Node Tuning Operator: core functionality is working #
#############################################################

# TODO - turn off colors on demand
# Setting the output colors


red = "\33[31m"
on_red = "\33[41m"
blue = "\33[34m"
on_blue = "\33[44m"
green = "\33[32"
on_green = "\33[42m"
reset = "\33[0m"


# TODO - move print/execute steps to some new utils file of find what is in SVT already
def print_title(title):
    print("Running test: {}{}{}".format(on_blue, title, reset))


def print_step(step_description):
    print("\nStep: {}{}{}".format(on_blue, step_description, reset))


def print_command(command_description):
    print("Executing command: {}{}{}".format(blue, command_description, reset))


def print_warning(warning):
    print("{}{}{}".format(red, warning, reset))


def passed(description):
    print("{}STEP PASSED{}".format(on_green, reset))
    if description is not None:
        print("{}{}{}".format(green, description, reset))


def fail(description):
    print("{}STEP FAILED{}".format(on_red, reset))
    if description is not None:
        print("{}{}{}".format(red, description, reset))
    raise SystemExit


def execute_command(command_to_execute):
    print_command(command_to_execute)
    try:
        value_to_return = subprocess.check_output(command_to_execute, shell=True)
    except subprocess.CalledProcessError as exc:
        value_to_return = exc.output
    return value_to_return


def execute_command_on_node(externall_address, node_address, command_to_execute):
    command_on_node = "ssh -i ~/.ssh/libra.pem -o ProxyCommand='ssh -A -i ~/.ssh/libra.pem -W %h:%p core@{}' core@{} {}".format(externall_address, node_address, command_to_execute)
    return execute_command(command_on_node)


# Test execution:
print_title("Node Tuning Operator: core functionality is working")

# Getting all nodes
print_step("Gathering information about nodes")
nodes = execute_command("oc get nodes --no-headers -o=custom-columns=NAME:.metadata.name").split("\n")
del nodes[-1]
# Getting DNS server
print_step("Getting DNS address")
external_dns = execute_command("oc get nodes -o jsonpath='{.items[*].status.addresses[?(@.type==\"ExternalDNS\")].address}' | cut -d ' ' -f 1")
# Getting all pods
print_step("Getting information about pods")
tuned_pods = execute_command("oc get pods --no-headers -o=custom-columns=NAME:.metadata.name | grep tuned").split("\n")
del tuned_pods[-1]  # split method is giving extra empty field after last line from response
passed(None)


# Verification if openshift-cluster-node-tuning-operator is running
print_step("Verification if openshift-cluster-node-tuning-operator is installed and running.")
execute_command("oc project openshift-cluster-node-tuning-operator")
number_of_deployments = execute_command("oc get deployment | grep -c cluster-node-tuning-operator")
print("Number of deployments: " + number_of_deployments)
if number_of_deployments == 0:
    fail("It looks like the openshift-cluster-node-tuning-operator is not running!")

# Verification if all nodes are tuned
number_of_tuned_clusters = execute_command("oc get ds | grep tuned | tr -s ' ' | cut -d ' ' -f 2")
number_of_working_nodes = execute_command("oc get nodes | grep -c Ready")
print("Number of tuned clusters: {}".format(number_of_tuned_clusters))
print("Number of working nodes: {}".format(number_of_working_nodes))
if number_of_tuned_clusters != number_of_working_nodes:
    fail("Not all nodes are tuned!")
passed(None)


# Verification that pod can be tuned
print_step("Verify that after creating new resource with 'es' label pod will be tuned")
tuning_applied_for_label_before = []
for pod in tuned_pods:
    tuning_applied_for_label_before.append(int(execute_command("oc logs {} | grep -c \"\'openshift-node-es\' applied\"".format(pod))))
time.sleep(1)
execute_command("oc new-project my-logging-project")
execute_command("oc create -f https://raw.githubusercontent.com/hongkailiu/svt-case-doc/master/files/pod_test.yaml")
execute_command("oc label pod web -n my-logging-project  tuned.openshift.io/elasticsearch=")
execute_command("oc project openshift-cluster-node-tuning-operator")
print("Waiting 15 seconds, to be sure changes has applied")
time.sleep(15)
tuning_applied_for_label_after = []
for pod in tuned_pods:
    tuning_applied_for_label_after.append(int(execute_command("oc logs {} | grep -c \"\'openshift-node-es\' applied\"".format(pod))))
print("\nResults:")
print("Pod\t\tBefore\tAfter")
for i in range(len(tuned_pods)):
    print("{}\t{}\t{}".format(tuned_pods[i], tuning_applied_for_label_before[i], tuning_applied_for_label_after[i]))
test_pass = False
for i in range(len(tuning_applied_for_label_before)):
    if tuning_applied_for_label_after[i] > tuning_applied_for_label_before[i]:
        test_pass = True
        passed(None)
        break
if not test_pass:
    fail("At least one of pods should be tuned")


# Verification that increasing net.netfilter.nf_conntrack_max will affect every node
print_step("Verify that modification (increase) of a parameter: net.netfilter.nf_conntrack_max will take effect on every node of the cluster.")
print("Checking logs of tuned pods on each node before test")
tuning_applied_before = []
for pod in tuned_pods:
    tuning_applied_before.append(int(execute_command("oc logs {} | grep -c applied".format(pod))))

conntract_max_before = int(execute_command("oc get tuned default -o yaml | grep \" net.netfilter.nf_conntrack_max\" | cut -d '=' -f 2"))
# Saving default configuration to file
print_step("Saving default configuration file")
execute_command("oc get tuned default -o yaml > default_values.yaml")
execute_command("sed -e \"s/ net.netfilter.nf_conntrack_max={}/ net.netfilter.nf_conntrack_max={}/\" default_values.yaml > new_conntract.yaml".format(conntract_max_before, conntract_max_before + 1))
execute_command("oc apply -f new_conntract.yaml")
print("Waiting 15 seconds, to be sure changes has applied")
time.sleep(15)
conntract_max_after = int(execute_command("oc get tuned default -o yaml | grep \" net.netfilter.nf_conntrack_max\" | cut -d '=' -f 2"))

for node in nodes:
    repeats = 0
    while True:
        conntract_max_on_node = int(execute_command_on_node(external_dns, node, "sysctl net.netfilter.nf_conntrack_max").rstrip().split("=")[1])
        if conntract_max_after == conntract_max_on_node:
            print("Match on node: {} with value: {}".format(node, conntract_max_on_node))
            break
        repeats += 1
        time.sleep(10)
        if repeats > 12:
            fail("On node {} net.netfilter.nf_conntrack_max is {} instead {}".format(node, conntract_max_on_node, conntract_max_after))

print("Checking logs of tuned pods on each node after test")
tuning_applied_after = []
for pod in tuned_pods:
    tuning_applied_after.append(int(execute_command("oc logs {} | grep -c applied".format(pod))))

print("\nResults:")
print("Pod\t\tBefore\tAfter")
for i in range(len(tuned_pods)):
    print("{}\t{}\t{}".format(tuned_pods[i], tuning_applied_before[i], tuning_applied_after[i]))

for i in range(len(tuning_applied_before)):
    if tuning_applied_after[i] == tuning_applied_before[i]:
        fail("At least one of pods should be tuned")
passed(None)


# Verification that decreasing net.netfilter.nf_conntrack_max will affect every node
print_step("Verify that modification (decrease) of a parameter: net.netfilter.nf_conntrack_max will take effect on every node of the cluster.")
print("Checking logs of tuned pods on each node before test")
tuning_applied_before = []
for pod in tuned_pods:
    tuning_applied_before.append(int(execute_command("oc logs {} | grep -c applied".format(pod))))

conntract_max_before = int(execute_command("cat default_values.yaml | grep \" net.netfilter.nf_conntrack_max\" | cut -d '=' -f 2"))
execute_command("oc get tuned default -o yaml > default_values.yaml")
execute_command("sed -e \"s/ net.netfilter.nf_conntrack_max={}/ net.netfilter.nf_conntrack_max={}/\" default_values.yaml > new_conntract.yaml".format(conntract_max_after, conntract_max_before))
execute_command("oc apply -f new_conntract.yaml")
print("Waiting 15 seconds, to be sure changes has applied")
time.sleep(15)
conntract_max_after = int(execute_command("oc get tuned default -o yaml | grep \" net.netfilter.nf_conntrack_max\" | cut -d '=' -f 2"))

for node in nodes:
    repeats = 0
    while True:
        conntract_max_on_node = int(execute_command_on_node(external_dns, node, "sysctl net.netfilter.nf_conntrack_max").rstrip().split("=")[1])
        if conntract_max_after == conntract_max_on_node:
            print("Match on node: {} with value: {}".format(node, conntract_max_on_node))
            break
        repeats += 1
        time.sleep(10)
        if repeats > 12:
            fail("On node {} net.netfilter.nf_conntrack_max is {} instead {}".format(node, conntract_max_on_node, conntract_max_after))

print("Checking logs of tuned pods on each node after test")
tuning_applied_after = []
for pod in tuned_pods:
    tuning_applied_after.append(int(execute_command("oc logs {} | grep -c applied".format(pod))))

print("\nResults:")
print("Pod\t\tBefore\tAfter")
for i in range(len(tuned_pods)):
    print("{}\t{}\t{}".format(tuned_pods[i], tuning_applied_before[i], tuning_applied_after[i]))

for i in range(len(tuning_applied_before)):
    if tuning_applied_after[i] == tuning_applied_before[i]:
        fail("At least one of pods should be tuned")
passed(None)


# Verification that increasing kernel.pid_max will affect every node
print_step("Verify that modification (increase) of a parameter: kernel.pid_max will take effect on every node of the cluster.")
print("Checking logs of tuned pods on each node before test")
tuning_applied_before = []
for pod in tuned_pods:
    tuning_applied_before.append(int(execute_command("oc logs {} | grep -c applied".format(pod))))

kernel_pid_max_before = int(execute_command_on_node(external_dns, nodes[0], "sysctl kernel.pid_max").rstrip().split("=")[1])
default_kernel_pid = int(execute_command("oc get tuned default -o yaml | grep \" kernel.pid_max\" | cut -d '>' -f 2").rstrip())
execute_command("oc get tuned default -o yaml > default_values.yaml")
execute_command("sed -e \"s/ kernel.pid_max=>{}/ kernel.pid_max=>{}/\" default_values.yaml > new_kernel_pid.yaml".format(default_kernel_pid, kernel_pid_max_before + 1))
execute_command("oc apply -f new_kernel_pid.yaml")
print("Waiting 15 seconds, to be sure changes has applied")
time.sleep(15)
kernel_pid_max_after = int(execute_command("oc get tuned default -o yaml | grep \" kernel.pid_max\" | cut -d '>' -f 2").rstrip())

for node in nodes:
    repeats = 0
    while True:
        kernel_pid_max_on_node = int(execute_command_on_node(external_dns, node, "sysctl kernel.pid_max").rstrip().split("=")[1])
        if kernel_pid_max_after == kernel_pid_max_on_node:
            print("Match on node: {} with value: {}".format(node, kernel_pid_max_on_node))
            break
        repeats += 1
        time.sleep(10)
        if repeats == 12:
            fail("On node {} kernel.pid_max is {} instead {}".format(node, kernel_pid_max_on_node, kernel_pid_max_after))

print("Checking logs of tuned pods on each node after test")
tuning_applied_after = []
for pod in tuned_pods:
    tuning_applied_after.append(int(execute_command("oc logs {} | grep -c applied".format(pod))))

print("\nResults:")
print("Pod\t\tBefore\tAfter")
for i in range(len(tuned_pods)):
    print("{}\t{}\t{}".format(tuned_pods[i], tuning_applied_before[i], tuning_applied_after[i]))

for i in range(len(tuning_applied_before)):
    if tuning_applied_after[i] == tuning_applied_before[i]:
        fail("At least one of pods should be tuned")
passed(None)


# Verification that decreasing kernel.pid_max will affect every node
print_step("Verify that modification (decrease) of a parameter: kernel.pid_max will NOT take effect on every node of the cluster.")
print("Checking logs of tuned pods on each node before test")
tuning_applied_before = []
for pod in tuned_pods:
    tuning_applied_before.append(int(execute_command("oc logs {} | grep -c applied".format(pod))))

kernel_pid_max_before = int(execute_command("oc get tuned default -o yaml | grep \" kernel.pid_max\" | cut -d '>' -f 2").rstrip())
execute_command("oc get tuned default -o yaml > default_values.yaml")
execute_command("sed -e \"s/ kernel.pid_max=>{}/ kernel.pid_max=>{}/\" default_values.yaml > new_kernel_pid.yaml".format(kernel_pid_max_before, default_kernel_pid))
execute_command("oc apply -f new_kernel_pid.yaml")
print("Waiting 15 seconds, to be sure changes has applied")
time.sleep(15)
kernel_pid_max_after = int(execute_command("oc get tuned default -o yaml | grep \" kernel.pid_max\" | cut -d '>' -f 2").rstrip())

repeats = 0
while True:
    print("Attempt #{}/12 starts in 10 seconds.".format(repeats + 1))
    for node in nodes:
        kernel_pid_max_on_node = int(execute_command_on_node(external_dns, node, "sysctl kernel.pid_max").rstrip().split("=")[1])
        if kernel_pid_max_before != kernel_pid_max_on_node:
            fail("On node {} kernel.pid_max is {} instead {}".format(node, kernel_pid_max_on_node, kernel_pid_max_after))
        else:
            print("Match on node: {} with value: {}".format(node, kernel_pid_max_on_node))
    repeats += 1
    if repeats == 12:
        break
    time.sleep(10)

print("Checking logs of tuned pods on each node after test")
tuning_applied_after = []
for pod in tuned_pods:
    tuning_applied_after.append(int(execute_command("oc logs {} | grep -c applied".format(pod))))

print("\nResults:")
print("Pod\t\tBefore\tAfter")
for i in range(len(tuned_pods)):
    print("{}\t{}\t{}".format(tuned_pods[i], tuning_applied_before[i], tuning_applied_after[i]))

for i in range(len(tuning_applied_before)):
    if tuning_applied_after[i] == tuning_applied_before[i]:
        fail("At least one of pods should be tuned")
passed(None)


# Verification that changing priority affect at least one node
print_step("Verify that after changing priority pod will be tuned")
print("Checking logs of tuned pods on each node before test")
tuning_applied_before = []
for pod in tuned_pods:
    tuning_applied_before.append(int(execute_command("oc logs {} | grep -c applied".format(pod))))

# Saving default configuration to file
print_step("Saving default configuration file")
execute_command("oc get tuned default -o yaml > default_values.yaml")
execute_command("sed -e \"s/ priority: 20/ priority: 15/\" default_values.yaml > new_priority.yaml")
execute_command("oc apply -f new_priority.yaml")
print("Waiting 15 seconds, to be sure changes has applied")
time.sleep(15)

tuning_applied_priority_after = []
for pod in tuned_pods:
    tuning_applied_priority_after.append(int(execute_command("oc logs {} | grep -c \"\'openshift-node-es\' applied\"".format(pod))))
print("\nResults:")
print("Pod\t\tBefore\tAfter")
for i in range(len(tuned_pods)):
    print("{}\t{}\t{}".format(tuned_pods[i], tuning_applied_before[i], tuning_applied_priority_after[i]))
test_pass = False
for i in range(len(tuning_applied_before)):
    if tuning_applied_priority_after[i] > tuning_applied_before[i]:
        test_pass = True
        passed(None)
        break
if not test_pass:
    fail("At least one of pods should be tuned")

# Cleaning after execution test
execute_command("oc delete project my-logging-project")
print_step("Saving default configuration file")
execute_command("oc get tuned default -o yaml > default_values.yaml")
execute_command("sed -e \"s/ priority: 15/ priority: 20/\" default_values.yaml > new_priority.yaml")
execute_command("oc apply -f new_priority.yaml")
