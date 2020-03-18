#!/usr/bin/env python

from utils import *

########################################################
# Test: Node Tuning Operator: custom tuning is working #
########################################################
# Changes:                                             #
#   skordas:                                           #
#   Updating Test Case to work with OCP 4.4            #
########################################################


def cleanup():
    print("Cleaning after test")
    execute_command("oc delete tuned nf-conntrack-max -n openshift-cluster-node-tuning-operator")
    execute_command("oc delete project my-logging-project")


def test():
    # Test execution:
    print_title("Node Tuning Operator: Custom tuning is working")

    # Getting all nodes
    print_step("Gathering information about nodes")
    nodes = execute_command("oc get nodes --no-headers -o=custom-columns=NAME:.metadata.name").split("\n")
    del nodes[-1]
    passed("List of nodes:\n" + str(nodes))

    # Getting all tuned pods in project
    print_step("Getting information about tuned pods pods")
    tuned_pods = execute_command("oc get pods -n openshift-cluster-node-tuning-operator --no-headers -o=custom-columns=NAME:.metadata.name | grep tuned").split("\n")
    del tuned_pods[-1]  # split method is giving extra empty field after last line from response
    passed("List of tuned pods:\n" + str(tuned_pods))

    # Creating test project
    print_step("Create project and get information where app is running")
    execute_command("oc new-project my-logging-project")
    execute_command("oc create -f https://raw.githubusercontent.com/hongkailiu/svt-case-doc/master/files/pod_test.yaml")
    countdown(10)
    execute_command("oc label pod web -n my-logging-project tuned.openshift.io/elasticsearch=")

    # Getting node where pod with 'web' name is running
    node_where_app_is_running = execute_command("oc get pod web --no-headers -o=custom-columns=NODE:.spec.nodeName").rstrip()
    tuned_operator_pod = execute_command("oc get pods -n openshift-cluster-node-tuning-operator -o wide | grep {} | cut -d ' ' -f 1".format(node_where_app_is_running))

    # Creation a new profile
    print_step("Create new profile: router")
    execute_command("oc create -f content/tuned-nf-conntrack-max.yml")

    # Verification if new tuned exist
    print_step("Verify if new tuned exist")
    number_of_tuned_router = int(execute_command("oc get tuned -n openshift-cluster-node-tuning-operator | grep -c nf-conntrack-max"))
    print("Number of tuned nf-conntrack-max: {}".format(number_of_tuned_router))
    if number_of_tuned_router == 1:
        passed(None)
    else:
        fail("There should be one tuned router but it was: {}".format(number_of_tuned_router), cleanup)
        return False

    # Verification if correct tuned applied on node
    print_step("Verify if correct profile is active on node")
    tuned_profiles_actual = execute_command("oc get profiles.tuned.openshift.io {} -n openshift-cluster-node-tuning-operator -o json | jq -r '.spec.config.tunedProfile'".format(node_where_app_is_running)).rstrip()
    if tuned_profiles_actual.replace(" ", "") == "nf-conntrack-max":
        passed(None)
    else:
        fail("Expected value:\nnf-conntrack-max\nActual value:\n{}".format(tuned_profiles_actual), cleanup)
        return False

    # Checking all nodes for net.ipv4.ip_local_port_range values on all nodes:
    print_step("Check all nodes for etfilter.nf_conntrack_max value")
    for node in nodes:
        conntrack_max = execute_command_on_node(node, "sysctl net.netfilter.nf_conntrack_max | cut -d ' ' -f 3 | sed 's/\t/ /g'").rstrip()
        print("Node:                      {}".format(node))
        print("etfilter.nf_conntrack_max: {}".format(conntrack_max))
        if (node in node_where_app_is_running and conntrack_max != "1048578") or (node not in node_where_app_is_running and conntrack_max == "1048578"):
            fail("On node {} net.netfilter.nf_conntrack_max is {}".format(node, conntrack_max), cleanup)
            return False
    passed(None)

    # Checking logs on every pod:
    print_step("Check logs on every pod")
    for pod in tuned_pods:
        log = execute_command("oc logs {} -n openshift-cluster-node-tuning-operator | grep profile | tail -n1".format(pod)).rstrip()
        print("Pod: {}".format(pod))
        print('Log: {}'.format(log))
        if (pod in tuned_operator_pod and "nf-conntrack-max" not in log) or (pod not in tuned_operator_pod and "nf-conntrack-max" in log):
            fail("On pod: {} founded log: {}".format(pod, log), cleanup)
            return False
    passed(None)

    # Cleaning after test
    print_step("Cleaning after test")
    cleanup()
    number_of_tuned_router = int(execute_command("oc get tuned | grep -c nf-conntrack-max"))
    if number_of_tuned_router == 0:
        passed(None)
    else:
        fail("It shouldn't be any tuned nf-conntrack-max, but it was: {}".format(number_of_tuned_router), cleanup)
        return False

    # All steps passed
    return True


if __name__ == "__main__":
    test()
