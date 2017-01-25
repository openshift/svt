import ansible.runner
import json
import argparse

from ansible                 import playbook
from ansible.inventory.host  import Host
from ansible.inventory.group import Group
from ansible.inventory       import Inventory
from ansible.callbacks       import AggregateStats
from ansible.callbacks       import PlaybookCallbacks
from ansible.callbacks       import PlaybookRunnerCallbacks
from ansible                 import utils

class StorageTest(object):
    def __init__(self, playbook):
        self.inventory = Inventory(host_list=[])
        self.playbook = playbook
        
        self.sender_group = Group(name = 'sender')
        self.inventory.add_group(self.sender_group)
        
        self.receiver_group = Group(name = 'receiver')
        self.inventory.add_group(self.receiver_group)
        
        self.master_group = Group(name = 'master')
        self.inventory.add_group(self.master_group)
        
        self.inv_vars = dict()

        
    def set_inventory_vars(self, inv_vars):
        self.inv_vars.update(inv_vars)


    def add_sender(self, sender):
        sender_host = Host(name = sender)
        self.sender_group.add_host(sender_host)


    def add_receiver(self, receiver):
        receiver_host = Host(name = receiver)
        self.receiver_group.add_host(receiver_host)

        
    def add_master(self, master):
        master_host = Host(name = master)
        self.master_group.add_host(master_host)


    def run(self):
        stats = AggregateStats()
        playbook_cb = PlaybookCallbacks(verbose=utils.VERBOSITY)
        runner_cb = PlaybookRunnerCallbacks(stats, verbose=utils.VERBOSITY)

        pb = playbook.PlayBook(playbook = self.playbook,
                               stats = stats,
                               callbacks = playbook_cb,
                               runner_callbacks = runner_cb,
                               inventory = self.inventory,
                               extra_vars = self.inv_vars,
                               check=False)

        pr = pb.run()

        print json.dumps(pr, sort_keys=True, indent=4, separators=(',', ': '))


def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument('test_type',
                        choices = ['podIP', 'svcIP', 'fio'])
    
    parser.add_argument('-m',
                        '--master',
                        required = True,
                        dest = 'test_master',
                        help = 'OpenShift master node')
    
    parser.add_argument('-n',
                        '--node',
                        required = True,
                        nargs = '*',
                        dest = 'test_nodes',
                        help = 'OpenShift node')

    parser.add_argument('-p',
                        '--pods',
                        required = False,
                        nargs = '*',
                        dest = 'pod_numbers',
                        type = int,
                        help = 'Sequence of pod numbers to test')
    
    return parser.parse_args()


def set_sender(master, nodes):
    if nodes is None or len(nodes) == 1:
        return master
    else:
        return nodes[0]
    

def set_receiver(master, nodes):
    if nodes is None:
        return master
    elif len(nodes) == 1:
        return nodes[0]
    elif len(nodes) == 2:
        return nodes[1]
    

def set_pbench_remote(master, nodes):
    if nodes is None:
        return 'None'
    elif len(nodes) == 1:
        return nodes[0]
    elif len(nodes) == 2:
        return nodes[1]
    

def set_sender_region(master, nodes):
    if nodes is None:
        return 'both'
    else:
        if len(nodes) == 2 and nodes[0] == nodes[1]:
            return 'both'
        return 'sender'
    

def set_receiver_region(master, nodes):
    if nodes is None:
        return 'both'
    else:
        if len(nodes) == 2 and nodes[0] == nodes[1]:
            return 'both'
        return 'receiver'
    
def set_playbook(test_type):
    if test_type == 'fio':
        return 'fio-test-setup.yaml'
    else:
        return 'svc-ip-test-setup.yaml'

def main():
    args = parse_args()
    
    sender_host = set_sender(args.test_master, args.test_nodes)
    receiver_host = set_receiver(args.test_master, args.test_nodes)
    master_host = args.test_master
    
    pbench_remote = set_pbench_remote(args.test_master, args.test_nodes)
    
    sender_region = set_sender_region(args.test_master, args.test_nodes)
    receiver_region = set_receiver_region(args.test_master, args.test_nodes)

    test_playbook = set_playbook(args.test_type)

    pbench_label = 'FIO'
    project_number = 1
        
    inventory_vars = { 'sender_region': sender_region,
                       'receiver_region': receiver_region,
                       'project_number': project_number,
                       'pbench_label': pbench_label,
                       'pbench_remote': pbench_remote }
    
    nettest = StorageTest(test_playbook)

    nettest.add_sender(sender_host)
    nettest.add_receiver(receiver_host)
    nettest.add_master(master_host)
    
    nettest.set_inventory_vars(inventory_vars)

    nettest.run()
    

if __name__ == '__main__':
    main()