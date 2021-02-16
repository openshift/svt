import subprocess
from optparse import OptionParser
import re
import time


def run(command):
    try:
        output = subprocess.Popen(command, shell=True,
                                  universal_newlines=True, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT)
        (out, err) = output.communicate()
    except Exception as e:
        print("Failed to run %s, error: %s" % (command, e))
    return out

def pods_in_nodes():
    nodes =run("oc get pods -A -o wide | grep svt | awk '{print $8}'")
    node_list = nodes.split('\n')
    node_json= {}
    for node in node_list:
        if node in node_json.keys():
            continue
        node_json[node] = node_list.count(node)

    print(node_json)


def see_if_error_builds(output_file):
    print('here')
    errorbuilds=run('oc get builds --all-namespaces | grep svt | egrep -v "Running|Complete|Creating|Pending"')
    with open(output_file, "a") as f:
        f.write(str(errorbuilds))
    print ("error builds" + str(errorbuilds))
    COUNTER=0
    error_builds_list = errorbuilds.split("\n")
    builds = []

    for val in error_builds_list:
        COUNTER = 0
        error_builds = []
        line = re.split(r'\s{2,}', val)
        for word in line:
            if ((COUNTER % 6 ) == 0 ):
                error_builds.append(word)
            elif ((COUNTER % 6 ) == 1):

                error_builds.append(word)
                builds.append(error_builds)
            else:
                break

            COUNTER += 1

    return builds


def get_error_builds(build_item):
    namespace = build_item[0]
    name = build_item[1]
    #append to file
    with open("build/" +name + namespace +".out", "w+") as f:
        f.write("Log info for " + name + " build in namespace "+ namespace + '\n')
        #logs = run("oc describe pod/" + str(name) + " -n " + namespace)
        #f.write("Describe pod " + str(logs) + '\n')
        logs = run("oc logs -f build/" + str(name) + " -n " + namespace)
        f.write("Logs build " + str(logs) + '\n')


def check_error_build(global_output_file):
    builds_list = see_if_error_builds(global_output_file)
    skip_first = True
    run("mkdir build")
    for build_item in builds_list:
        if skip_first:
            skip_first = False
        else:
            get_error_builds(build_item)

def see_if_error(output_file):
    print('here')
    errorpods=run('oc get pods --all-namespaces | grep svt | egrep -v "Running|Complete|Creating|Pending"')
    with open(output_file, "a") as f:
        f.write(str(errorpods))
    print ("errorpods" + str(errorpods) + str(type(errorpods)))
    COUNTER=0
    error_pods_list = errorpods.split("\n")
    pods = []

    for val in error_pods_list:
        COUNTER = 0
        error_pods = []
        line = re.split(r'\s{2,}', val)
        for word in line:
            if ((COUNTER % 6 ) == 0 ):
                error_pods.append(word)
            elif ((COUNTER % 6 ) == 1):

                error_pods.append(word)
                pods.append(error_pods)
            else:
                break

            COUNTER += 1

    return pods


def get_error_logs(pod_item, output_file):
    namespace = pod_item[0]
    name = pod_item[1]
    #append to file
    with open("pod/" + name + namespace +".out", "w+") as f:
        f.write("Debugging info for " + name + " in namespace "+ namespace + '\n')
        logs = run("oc logs " + str(name) + " -n " + namespace)
        f.write("Logs " + str(logs) + '\n')



def check_error(global_output_file):
    pods_list = see_if_error(global_output_file)
    skip_first = True
    run("mkdir pod")
    for pod_item in pods_list:
        if skip_first:
            skip_first = False
        else:
            get_error_logs(pod_item, global_output_file)

pods_in_nodes()
check_error("pod_error.out")
check_error_build("build_error.out")