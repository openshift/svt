#!/usr/bin/env python

from utils import *

###########################################
# Test: Node Tuning Operator: Daemon node #
###########################################

expected_max_map_count = 262144


def cleanup():
    print("Cleaning after test")
    execute_command("oc label pods --all tuned.openshift.io/elasticsearch-")


def test():
    # Changing project and getting base information to run test
    print_step("Changing project to 'openshift-cluster-node-tuning-operator'")
    execute_command("oc project openshift-cluster-node-tuning-operator")

    # Getting all nodes
    print_step("Gathering information about nodes")
    nodes = execute_command("oc get nodes --no-headers -o=custom-columns=NAME:.metadata.name").split("\n")
    del nodes[-1]
    passed("List of nodes:\n" + str(nodes))

    # Getting all pods in project
    print_step("Getting information about pods")
    pods = execute_command("oc get pods --no-headers -o=custom-columns=NAME:.metadata.name | grep tuned").split("\n")
    del pods[-1]  # split method is giving extra empty field after last line from response
    passed("List of tuned pods:\n" + str(pods))

    # Test execution:
    print_title("Node Tuning Operator - daemon mode - removing pod")
    for pod in pods:
        print_step("Labeling pod: {}".format(pod))
        execute_command("oc label pod {} tuned.openshift.io/elasticsearch=".format(pod))
        countdown(15)
        print_step("Verifying vm.max_map_count value on all nodes")
        max_map_count = []
        for node in nodes:
            max_map_count.append(int(execute_command_on_node(node, "sysctl vm.max_map_count | cut -d ' ' -f 3").rstrip()))
        if expected_max_map_count not in max_map_count:
            fail("vm.max_map_count with value 262144 should be at least on one node\n" + str(max_map_count), cleanup)
            return False
        else:
            passed("vm.max_map_count values: " + str(max_map_count))
        del max_map_count[:]

        print_step("Removing pod: {}".format(pod))
        execute_command("oc delete pod {}".format(pod))
        countdown(15)
        print_step("Verifying vm.max_map_count value on all nodes")
        max_map_count = []
        for node in nodes:
            max_map_count.append(int(execute_command_on_node(node, "sysctl vm.max_map_count | cut -d ' ' -f 3").rstrip()))
        if expected_max_map_count in max_map_count:
            fail("vm.max_map_count with value 262144 shouldn't be on any node\n" + str(max_map_count), cleanup)
            return False
        else:
            passed("vm.max_map_count values: " + str(max_map_count))
        del max_map_count[:]

    print_step("Cleaning after test")
    cleanup()

    # All steps passed
    return True


if __name__ == "__main__":
    test()
