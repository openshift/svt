#!/usr/bin/env python

from utils import *

#############################################################
# Test: Node Tuning Operator: core functionality is working #
#############################################################
# Changes:                                                  #
#   skordas:                                                #
#   Updating Test Case to work with OCP 4.4                 #
#############################################################


max_map_count = 262144


def cleanup():
    print("Cleaning after test")
    execute_command("oc delete project my-logging-project")


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
        count.append(int(execute_command("oc logs {} -n openshift-cluster-node-tuning-operator | grep -c \"\'{}\' applied\"".format(pod_in_list['pod'], applied_profile))))
    print(count)
    return count


def test():
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
        return False

    # Verification if all nodes are tuned
    number_of_tuned_clusters = execute_command("oc get ds | grep tuned | tr -s ' ' | cut -d ' ' -f 2")
    number_of_working_nodes = execute_command("oc get nodes | grep -c Ready")
    print("Number of tuned clusters: {}".format(number_of_tuned_clusters))
    print("Number of working nodes: {}".format(number_of_working_nodes))
    if number_of_tuned_clusters != number_of_working_nodes:
        fail("Not all nodes are tuned!", cleanup)
        return False
    passed(None)

    # Getting number of secrets
    print_step("Getting number of secrets")
    number_of_secrets_at_beginning = int(execute_command("oc get secrets -n openshift-cluster-node-tuning-operator | wc -l"))
    if number_of_secrets_at_beginning == 0:
        fail("No secrets for openshift-cluster-node-tuning-operator projects", cleanup)
        return False
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

    print("Pod running on node: {} with role: {} - profile to verify: {}".format(node_where_app_is_running, node_type, profile))
    execute_command("oc project openshift-cluster-node-tuning-operator")
    tuned_pod = execute_command("oc get pods -o wide | grep tuned | grep {} | cut -d ' ' -f 1".format(node_where_app_is_running)).rstrip()
    passed(None)

    # Verification that node tuning operator apply new vm.max_map_count on correct nodes
    print_step("Verification that node tuning operator apply new vm.max_map_count on correct nodes.")
    print("Checking logs of tuned pods on each node before test")
    tuning_applied_before = count_log_applied_lines(tuned_pods, node_where_app_is_running)
    execute_command("oc label pod web -n my-logging-project  tuned.openshift.io/elasticsearch=")
    countdown(10)

    # Checking every node
    for pod in tuned_pods:
        repeats = 0
        while True:
            max_map_count_on_node = int(execute_command_on_node(pod['node'], "sysctl vm.max_map_count").rstrip().split("=")[1])
            if (pod['pod'] == tuned_pod and max_map_count == max_map_count_on_node) or (pod['pod'] != tuned_pod and max_map_count != max_map_count_on_node ):
                print("Match on node: {}, on pod: {}, with value: {}".format(pod['node'], pod['pod'], max_map_count_on_node))
                break
            repeats += 1
            countdown(10)
            if repeats == 12:
                fail("On node {} kernel.pid_max is {} instead {}".format(pod['node'], max_map_count_on_node, max_map_count), cleanup)
                return False

    print("Checking logs of tuned pods on each node after test")
    tuning_applied_after = count_log_applied_lines(tuned_pods, node_where_app_is_running)
    print("\nResults:")
    print("Pod\t\tBefore\tAfter")
    for i in range(len(tuned_pods)):
        print("{}\t{}\t{}".format(tuned_pods[i]['pod'], tuning_applied_before[i], tuning_applied_after[i]))

    should_pass = False
    for i in range(len(tuning_applied_before)):
        if tuning_applied_after[i] > tuning_applied_before[i]:
            should_pass = True

    if not should_pass:
        fail("All pods should be tuned.", cleanup)
        return False
    passed(None)

    # Getting number of secrets after tests
    print_step("Getting number of secrets after test")
    number_of_secrets_at_end = int(execute_command("oc get secrets -n openshift-cluster-node-tuning-operator | wc -l"))
    if number_of_secrets_at_beginning != number_of_secrets_at_end:
        fail("Number of secrets before and after not matching.\nAt beginning of test: {}\nAt end of test: {}".format(number_of_secrets_at_beginning, number_of_secrets_at_end), cleanup)
        return False
    passed("Number of secrets are matching\nAt beginning of test: {}\nAt end of test: {}".format(number_of_secrets_at_beginning, number_of_secrets_at_end))

    # Cleaning after tests when each step pass.
    cleanup()
    return True


if __name__ == "__main__":
    test()