import argparse
from decimal import Decimal
import json

from collections import namedtuple

from ansible.parsing.dataloader import DataLoader
from ansible.vars import VariableManager
from ansible.inventory import Inventory
from ansible.executor.playbook_executor import PlaybookExecutor

from ansible import utils
from ansible.inventory import Inventory
from ansible.inventory.group import Group
from ansible.inventory.host import Host

class StorageTest(object):
    def __init__(self, playbook):
        self.variable_manager = VariableManager()
        self.loader = DataLoader()
        self.inventory = Inventory(loader=self.loader, variable_manager=self.variable_manager,host_list=[])
        self.variable_manager.set_inventory(self.inventory)
        self.playbook = playbook
        
        self.sender_group = Group(name = 'sender')
        self.inventory.add_group(self.sender_group)
        
        self.receiver_group = Group(name = 'receiver')
        self.inventory.add_group(self.receiver_group)
        
        self.master_group = Group(name = 'master')
        self.inventory.add_group(self.master_group)
        
    def set_inventory_vars(self, inv_vars):
        self.variable_manager.extra_vars = inv_vars


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
        Options = namedtuple('Options', 
                             ['listtags', 'listtasks', 'listhosts', 
                              'syntax', 'connection', 'module_path', 
                              'forks', 'remote_user', 'private_key_file', 
                              'ssh_common_args', 'ssh_extra_args', 'sftp_extra_args', 
                              'scp_extra_args', 'become', 'become_method', 
                              'become_user', 'verbosity', 'check'])
        options = Options(listtags=False, listtasks=False, listhosts=False, 
                          syntax=False, connection='ssh', module_path=None, 
                          forks=100, remote_user='root', private_key_file=None, 
                          ssh_common_args=None, ssh_extra_args=None, sftp_extra_args=None, 
                          scp_extra_args=None, become=True, become_method=None, 
                          become_user='root', verbosity=None, check=False)

        passwords = {}

        pbex = PlaybookExecutor(playbooks=[self.playbook], 
                                inventory=self.inventory, 
                                variable_manager=self.variable_manager, 
                                loader=self.loader, 
                                options=options, 
                                passwords=passwords)
        results = pbex.run()
        
        print json.dumps(results, sort_keys=True, indent=4, separators=(',', ': '))


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