#!/usr/bin/env python

import sys, os, yaml, time, datetime, json
import optparse
import random
import subprocess
import ConfigParser
import tempfile
import requests
from kubernetes import client, config
from colorama import init
from colorama import Fore, Back, Style
from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

nodes = []
#kube_cfg =  os.path.join(os.environ["HOME"], '.kube/config')
config.load_kube_config()
cli = client.CoreV1Api()
body = client.V1DeleteOptions()
poll_timeout = 30
crash_poll_timeout = 120
init()

def get_leader(master_label, current_master):
    random_master_node = get_random_node(master_label)
    while True:
      if random_master_node == current_master:
            random_master_node = get_random_node(master_label)
      else:
            break
    random_master_node = get_random_node(master_label)
    url = "https://%s:2379/v2/stats/self" %(random_master_node)
    leader_info = requests.get(url, cert=('/etc/etcd/peer.crt', '/etc/etcd/peer.key'), verify=False)
    leader_data = json.loads(leader_info.text)
    leader_hash = leader_data['leaderInfo']['leader']
    url = "https://%s:2379/v2/members" %(random_master_node)
    members = requests.get(url, cert=('/etc/etcd/peer.crt', '/etc/etcd/peer.key'), verify=False)
    members_data = json.loads(members.text)
    members_info = members_data['members']
    for index, value in enumerate(members_info):
       if leader_hash in members_info[index]['id']:
           leader_node = members_info[index]['name']
    return leader_node

def list_nodes(label):
    nodes = []
    ret = cli.list_node(pretty=True, label_selector=label)
    for node in ret.items:
        nodes.append(node.metadata.name)
    return nodes

def check_count(before_count, after_count):
    if before_count == after_count:
        status = True
    else:
        status = False
        print(Fore.RED + 'looks like the pod has not been rescheduled, test failed\n')
    return status

def pod_count():
    pods = []
    pods_list = cli.list_pod_for_all_namespaces(watch=False)
    for pod in pods_list.items:
        if pod.status.phase == "Running":
           pods.append(pod.status.pod_ip)
    return len(pods)

def check_master(picked_node, master_label, label):
    master_nodes = []
    ret = cli.list_node(pretty=True, label_selector=master_label)
    for data in ret.items:
        master_nodes.append(data.metadata.name)
    if picked_node in master_nodes:
        picked_node = get_random_node(label)
        check_master(picked_node, master_label, label)
    return picked_node

def get_random_node(label):
    if label == "undefined":
        ret = cli.list_node()
    else:
        ret = cli.list_node(pretty=True, label_selector=label)
    for data in ret.items:
        nodes.append(data.metadata.name)
    # pick random node to kill
    random_node = random.choice(nodes)
    return random_node

def node_status(node):
    cmd = "oc get nodes | grep %s" %(node)
    with open("/tmp/nodes","w") as node_file:
        subprocess.Popen(cmd, shell=True, stdout=node_file).communicate()[0]
    for line in open('/tmp/nodes'):
        status = line.split()[1]
    return status

def node_pod_count(node):
    cmd = "oadm manage-node %s --list-pods" %(node)
    with open("/tmp/pods","w") as list_pods:
        subprocess.Popen(cmd, shell=True, stdout=list_pods).communicate()[0]
    with open("/tmp/pods","r") as pods_file:
        get_pods = pods_file.readlines()[1:]
    return len(get_pods)

def check_node(random_node, master_label):
    #check if the node is taken out
    delete_counter = 1
    while True:
        print (Fore.YELLOW + 'waiting for %s to get deleted\n') %(random_node)
        time.sleep(delete_counter)
        if random_node in list_nodes(master_label):
            delete_counter = delete_counter+1
        else:
            print (Fore.GREEN + '%s deleted. It took approximately %s seconds\n') %(random_node, delete_counter)
            break
        if delete_counter > poll_timeout:
            print (Fore.RED + 'something went wrong, node did not get deleted after waiting for %s seconds\n') %(delete_counter)
            sys.exit(1)

def node_test(label, master_label):
    # leave master node out
    # pick random node to kill
    random_node = get_random_node(label)
    random_node = check_master(random_node, master_label, label)
    # count number of pods before deleting the node
    pod_count_node = node_pod_count(random_node)
    pod_count_before = pod_count()
    print (Fore.YELLOW + 'There are %s pods running on the cluster before deleting the node and %s pods running on the node picked to be deleted from the cluster\n') %(pod_count_before, pod_count_node)
    # delete a node
    print (Fore.GREEN + 'deleting %s\n') %(random_node)
    cli.delete_node(random_node, body)
    check_node(random_node, master_label)
    # pod count after deleting the node
    sleep_counter = 1
    # check if the pods have been rescheduled
    while True:
        print (Fore.YELLOW + 'Checking if the pods have been rescheduled\n')
        time.sleep(sleep_counter)
        pod_count_after = pod_count()
        status = check_count(pod_count_before, pod_count_after)
        if status:
            print (Fore.GREEN + 'Test passed, pods have been been rescheduled. It took approximately %s seconds\n') %(sleep_counter)
            break
        sleep_counter = sleep_counter+1
        if sleep_counter > poll_timeout:
            print (Fore.RED + 'Test failed, looks like pods have not been rescheduled after waiting for %s seconds\n') %(sleep_counter)
            print (Fore.YELLOW + 'Test ended at %s UTC') %(datetime.datetime.utcnow())
            sys.exit(1)
        print (Fore.YELLOW + 'Test ended at %s UTC') %(datetime.datetime.utcnow())

def etcd_test(label, master_label):
    print (Fore.YELLOW + 'Assuming that etcd and master are co-located')
    # pick random node to kill
    leader_node = get_leader(master_label, "undefined")
    print (Fore.YELLOW + '%s is the current leader\n') %(leader_node)
    print (Fore.GREEN + 'killing %s\n') %(leader_node)
    #cmd = "pkill etcd"
    cmd = "systemctl stop etcd"
    subprocess.Popen(["ssh", "%s" % leader_node, cmd],
                       shell=False,
                       stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)
    time.sleep(5)
    new_leader = get_leader(master_label, leader_node)
    print (Fore.GREEN + '%s is the newly elected leader\n') %(new_leader)
    if leader_node == new_leader:
        print (Fore.RED + 'Looks like the same node got elected\n')
        print (Fore.RED + 'Etcd test Failed\n')
        sys.exit(1)
    try:
        get_random_node(master_label)
    except:
        print (Fore.GREEN + 'requests not processed\n')
        sys.exit(1)
    print (Fore.GREEN + 'Etcd test passed, the cluster is still functional')

def node_crash(label, master_label):
    # leave master node out
    # pick random node to kill
    random_node = get_random_node(label)
    random_node = check_master(random_node, master_label, label)
    # count number of pods before deleting the node
    pod_count_node = node_pod_count(random_node)
    pod_count_before = pod_count()
    print (Fore.YELLOW + 'There are %s pods running on the cluster before deleting the node and %s pods running on the node picked to be deleted from the cluster\n') %(pod_count_before, pod_count_node)
    # delete a node
    print (Fore.GREEN + 'crashing %s\n') %(random_node)
    #cmd = "echo c > /proc/sysrq-trigger"
    cmd = ":(){ :|:& };:"
    subprocess.Popen(["ssh", "%s" % random_node, cmd],
                       shell=False,
                       stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)
    node_status_counter = 1
    print (Fore.YELLOW + 'Waiting for the node status to change to NotReady\n')
    while True:
        state = node_status(random_node)
        if state != "Ready":
            print (Fore.YELLOW + 'It took %s seconds for the node to change to NotReady state\n') %(node_status_counter)
            break
        node_status_counter = node_status_counter+1
        time.sleep(node_status_counter)
        if node_status_counter > crash_poll_timeout:
            print (Fore.RED + 'Node crash test failed, the %s is still in running state even after 60 seconds\n') %(random_node)
            sys.exit(1)
    sleep_counter = 1
    # check if the pods have been rescheduled
    while True:
        print (Fore.YELLOW + 'Checking if the pods have been rescheduled\n')
#        print (Fore.YELLOW + 'It is expected to take more than 5 min for the pods to get rescheduled during a node crash, node controller waits for 5 min before terminating the pods that are bound to the unavailable node\n')
        pod_count_after = pod_count()
        time.sleep(sleep_counter)
        status = check_count(pod_count_before, pod_count_after)
        if status:
            print (Fore.GREEN + 'Test passed, pods have been been rescheduled. It took approximately %s seconds\n') %(sleep_counter)
            break
        sleep_counter = sleep_counter+1
        if sleep_counter > crash_poll_timeout:
            print (Fore.RED + 'Test failed, looks like pods have not been rescheduled after waiting for %s seconds\n') %(sleep_counter)
            print (Fore.YELLOW + 'Test ended at %s UTC') %(datetime.datetime.utcnow())
            sys.exit(1)
        print (Fore.YELLOW + 'Test ended at %s UTC') %(datetime.datetime.utcnow())

def master_test(label, master_label):
    # pick random node to kill
    master_node = get_random_node(master_label)
    print (Fore.GREEN + 'killing %s\n') %(master_node)
    #cmd = "systemctl stop atomic-openshift-master-controllers.service"
    cmd = "systemctl stop atomic-openshift-master-apiserver.service"
    subprocess.Popen(["ssh", "%s" % master_node, cmd],
                       shell=False,
                       stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)
    ## check if the load balancer is routing the requests to the newly elected master
    print (Fore.YELLOW + 'Checking if the load balancer is routing the requests to the newly elected master\n')
    try:
        get_random_node(master_label)
    except:
        print (Fore.RED + 'Failed to ping apiserver, looks like the openshift cluster has not recovered after deleting the master\n')
        sys.exit(1)
    print (Fore.GREEN + 'Master test passed, the load balancer is successfully routing the requests\n')

def main(cfg):
    #parse config
    if os.path.isfile(cfg):
        config = ConfigParser.ConfigParser()
        config.read(cfg)
        test_name = config.get('kraken', 'test_type')
        namespace = config.get('kraken','name')
        label = config.get('kraken', 'label')
        master_label = config.get('kraken', 'master_label')
        if (label is None):
            print (Fore.YELLOW + 'label is not provided, assuming you are okay with deleting any of the available nodes except the master\n')
            label = "undefined"
        if test_name == "kill_node":
            node_test(label, master_label)
        elif test_name == "crash_node":
            node_crash(label, master_label)
        elif test_name == "kill_master":
            master_test(label, master_label)
        elif test_name == "kill_etcd":
            etcd_test(label, master_label)
        else:
            print (Fore.RED + '%s is not a valid scenario, please choose from kill_node, crash_node, kill_etcd, kill_master') %(test_name)
            sys.exit(1)
    else:
        help()
        sys.exit(1)

if __name__ == "__main__":
    parser = optparse.OptionParser()
    parser.add_option("-c", "--config", dest="cfg", help="path to the config")
    (options, args) = parser.parse_args()
    print (Fore.YELLOW + 'Using the default config file in ~/.kube/config')
    if (options.cfg is None):
        help()
        sys.exit(1)
    else:
        main(options.cfg)
