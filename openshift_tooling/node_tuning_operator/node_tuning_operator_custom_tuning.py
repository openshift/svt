#!/usr/bin/env python

from utils import *

########################################################
# Test: Node Tuning Operator: custom tuning is working #
########################################################


def cleanup():
    print("Cleaning after test")
    execute_command("oc delete tuned router")


# Test execution:
print_title("Node Tuning Operator: Custom tuning is working")

# Getting all nodes
print_step("Gathering information about nodes")
nodes = execute_command("oc get nodes --no-headers -o=custom-columns=NAME:.metadata.name").split("\n")
del nodes[-1]
passed("List of nodes:\n" + str(nodes))

# Changing project and getting base information to run test
print_step("Changing project to 'openshift-cluster-node-tuning-operator'")
execute_command("oc project openshift-cluster-node-tuning-operator")
print_step("Getting current apiVersion")
api_version = execute_command("oc get tuned default -o json | jq -r .apiVersion").rstrip()
print("apiVersion: {}".format(api_version))

# Getting all pods in project
print_step("Getting information about pods")
tuned_pods = execute_command("oc get pods --no-headers -o=custom-columns=NAME:.metadata.name | grep tuned").split("\n")
del tuned_pods[-1]  # split method is giving extra empty field after last line from response
passed("List of tuned pods:\n" + str(tuned_pods))

# Creation a new profile
print_step("Create new profile: router")
create_tuned_router_command = """oc create -f - <<EOF
apiVersion: {}
kind: Tuned
metadata:
  name: router
  namespace: openshift-cluster-node-tuning-operator
spec:
  profile:
  - data: |
      [main]
      summary=A custom OpenShift profile for the router
      include=openshift-control-plane

      [sysctl]
      net.ipv4.ip_local_port_range="1024 65535"
      net.ipv4.tcp_tw_reuse=1

    name: openshift-router

  recommend:
  - match:
    - label: deployment-ingresscontroller
      value: default
      type: pod
    priority: 5
    profile: openshift-router
EOF""".format(api_version)
execute_command(create_tuned_router_command)
print("Wait 120 seconds to be sure change has applied.")
countdown(120)

# Verification if new tuned exist
print_step("Verify if new tuned exist")
number_of_tuned_router = int(execute_command("oc get tuned | grep -c router"))
print("Number of tuned router: {}".format(number_of_tuned_router))
if number_of_tuned_router == 1:
    passed(None)
else:
    fail("There should be one tuned router but it was: {}".format(number_of_tuned_router), cleanup)

# Verification if custom tuning applied to tuned-profiles
print_step("Verify if custom tuning applied to tuned-profiles")
tuned_profiles_expected = """    openshift-router: |
      summary=A custom OpenShift profile for the router
    name: router"""
tuned_profiles_actual = execute_command("oc get cm/tuned-profiles -o yaml | grep router").rstrip()
if tuned_profiles_actual == tuned_profiles_expected:
    passed(None)
else:
    fail("Expected value:\n{}\nActual value:\n{}".format(tuned_profiles_expected, tuned_profiles_actual), cleanup)

# Verification if custom tuning applied to tuned-recommend
print_step("Verify if custom tuning applied to tuned-recommend")
tuned_recommend_expected = """    [openshift-router,0]
    /var/lib/tuned/ocp-pod-labels.cfg=.*\\bdeployment-ingresscontroller=default\\n
    name: router"""
tuned_recommend_actual = execute_command("oc get cm/tuned-recommend -o yaml | grep -e router -e deployment-ingresscontroller").rstrip()
if tuned_recommend_actual == tuned_recommend_expected:
    passed(None)
else:
    fail("Expected value:\n{}\nActual value:\n{}".format(tuned_recommend_expected, tuned_recommend_actual), cleanup)

# Checking which nodes are tuned with router profile:
print_step("Check which node is tuned by router profile")
tuned_router_nodes = execute_command("oc get pods --all-namespaces --show-labels -o wide | grep  router | tr -s ' ' | cut -d ' ' -f 8").rstrip().split("\n")
print("tuned router node: {}".format(tuned_router_nodes))

# Checking all nodes for net.ipv4.ip_local_port_range values on all nodes:
print_step("Check all nodes for net.ipv4.ip_local_port_range value")
for node in nodes:
    ip_local_port_range = execute_command_on_node(node, "sysctl net.ipv4.ip_local_port_range | cut -d ' ' -f 3 | sed 's/\t/ /g'").rstrip()
    print("Node:                         {}".format(node))
    print("net.ipv4.ip_local_port_range: {}".format(ip_local_port_range))
    if (node in tuned_router_nodes and ip_local_port_range != "1024 65535") or (node not in tuned_router_nodes and ip_local_port_range == "1024 65535"):
        fail("On node {} net.ipv4.ip_local_port_range is {}".format(node, ip_local_port_range), cleanup)
passed(None)

# Checking all nodes for net.ipv4.tcp_tw_reuse values on all nodes:
print_step("Check all nodes for net.ipv4.tcp_tw_reuse value:")
for node in nodes:
    tcp_tw_reuse = int(execute_command_on_node(node, "sysctl net.ipv4.tcp_tw_reuse | cut -d ' ' -f 3").rstrip())
    print("Node: {}".format(node))
    print("net.ipv4.tcp_tw_reuse: {}".format(tcp_tw_reuse))
    if (node in tuned_router_nodes and tcp_tw_reuse != 1) or (node not in tuned_router_nodes and tcp_tw_reuse == 1):
        fail("On node {} net.ipv4.tcp_tw_reuse is {}".format(node, tcp_tw_reuse), cleanup)
passed(None)

# Checking which pod is tuned with router profile:
print_step("Get tuned pod on node with applied router profile:")
tuned_router_pods = []
for node in tuned_router_nodes:
    tuned_router_pods.append(execute_command("oc get pods -o wide | grep {} | cut -d ' ' -f 1".format(node)).rstrip())
print("tuned router pods: {}".format(tuned_router_pods))

# Checking logs on every pod:
print_step("Check logs on every pod")
for pod in tuned_pods:
    log = execute_command("oc logs {} | grep profile | tail -n1".format(pod)).rstrip()
    print("Pod: {}".format(pod))
    print('Log: {}'.format(log))
    if (pod in tuned_router_pods and "openshift-router" not in log) or (pod not in tuned_router_pods and "openshift-router" in log):
        fail("On pod: {} founded log: {}".format(pod, log), cleanup)
passed(None)

# Checking if pods are correct labeled
print_step("Check pods labels")
for node in nodes:
    number_of_labeled_pods = int(execute_command("oc get pod -n openshift-ingress --show-labels -o wide | grep {} | grep -c router-default".format(node)))
    if (node in tuned_router_nodes and number_of_labeled_pods == 0) or (node not in tuned_router_nodes and number_of_labeled_pods != 0):
        fail("On node: {} founded {} labeled pods".format(node, number_of_labeled_pods))
passed(None)

# Cleaning after test
print_step("Cleaning after test")
cleanup()
number_of_tuned_router = int(execute_command("oc get tuned | grep -c router"))
if number_of_tuned_router == 0:
    passed(None)
else:
    fail("It shouldn't be any tuned router, but it was: {}".format(number_of_tuned_router), cleanup)
