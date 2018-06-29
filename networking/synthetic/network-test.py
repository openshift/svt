import argparse
from decimal import Decimal
import json

from collections import namedtuple

from ansible.parsing.dataloader import DataLoader
from ansible.vars.manager import VariableManager
from ansible.executor.playbook_executor import PlaybookExecutor

from ansible import utils
from ansible.inventory.manager import InventoryManager

class NetworkTest(object):
    def __init__(self, playbook):
        self.loader = DataLoader()
        self.inventory = InventoryManager(loader=self.loader, sources=None)
        self.variable_manager = VariableManager(self.loader,self.inventory)
        self.playbook = playbook
        
        self.sender_group = 'sender'
        self.inventory.add_group(self.sender_group)
        
        self.receiver_group = 'receiver'
        self.inventory.add_group(self.receiver_group)
        
        self.master_group = 'master'
        self.inventory.add_group(self.master_group)
        
    def set_inventory_vars(self, inv_vars):
        self.variable_manager.extra_vars = inv_vars


    def add_sender(self, sender):
        sender_host =  sender
        self.inventory.add_host(sender_host, self.sender_group)


    def add_receiver(self, receiver):
        receiver_host = receiver
        self.inventory.add_host(receiver_host, self.receiver_group)

        
    def add_master(self, master):
        master_host = master
        self.inventory.add_host(master_host, self.master_group)


    def run(self):

        Options = namedtuple('Options', 
                             ['listtags', 'listtasks', 'listhosts', 
                              'syntax', 'connection', 'module_path', 
                              'forks', 'remote_user', 'private_key_file', 
                              'ssh_common_args', 'ssh_extra_args', 'sftp_extra_args', 
                              'scp_extra_args', 'become', 'become_method', 
                              'become_user', 'verbosity', 'check', 'diff'])
        options = Options(listtags=False, listtasks=False, listhosts=False, 
                          syntax=False, connection='ssh', module_path=None, 
                          forks=100, remote_user='root', private_key_file=None, 
                          ssh_common_args=None, ssh_extra_args=None, sftp_extra_args=None, 
                          scp_extra_args=None, become=True, become_method=None, 
                          become_user='root', verbosity=None, check=False, diff=False)
        #OPTION_FLAGS = ('connection', 'remote_user', 'private_key_file', 'verbosity', 'force_handlers', 'step', 'start_at_task', 'diff',
        #        'ssh_common_args', 'docker_extra_args', 'sftp_extra_args', 'scp_extra_args', 'ssh_extra_args')
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
                        choices=['podIP', 'svcIP', 'nodeIP'])
    
    parser.add_argument('-v',
                        '--version',
                        required = False,
                        dest = 'os_version',
                        default = '3.5',
                        help = 'OpenShift version')
    
    parser.add_argument('-a',
                        '--tcp_tests',
                        required = False,
                        dest = 'tcp_tests',
                        default = 'stream,rr',
                        help = 'The network test types (stream, request-response')

    parser.add_argument('-b',
                        '--udp_tests',
                        required = False,
                        dest = 'udp_tests',
                        default = 'stream,rr',
                        help = 'The network test types, have to be comma seperated.')

    parser.add_argument('-s',
                        '--message-sizes',
                        required = False,
                        dest = 'msg_sizes',
                        default = '64,1024,16384',
                        help = 'The sizes of messages to be used to perform the tests, have to be comma seperated')

    parser.add_argument('-t',
                        '--total-samples',
                        required = False,
                        dest = 'total_samples',
                        default = '3',
                        help = 'Number of samples to be used for the tests')

    parser.add_argument('-m',
                        '--master',
                        required = True,
                        dest = 'test_master',
                        help = 'OpenShift master node')
    
    parser.add_argument('-n',
                        '--node',
                        required = False,
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
    

def set_pbench_remotes(master, nodes):
    if nodes is None:
        return 'None'
    elif len(nodes) >= 1:
        return nodes

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
    if test_type == 'podIP':
        return 'pod-ip-test-setup.yaml'
    elif test_type == 'nodeIP':
        return 'node-ip-test-setup.yaml'
    else:
        return 'svc-ip-test-setup.yaml'


def set_pbench_label(test_type, nodes):
    if test_type == 'podIP':
        if nodes is None:
            return 'pod-to-pod-LB'
        elif len(nodes) == 1:
            return 'pod-to-pod-MN'
        elif len(nodes) == 2 and nodes[0] == nodes[1]:
            return 'pod-to-pod-LB'
        elif len(nodes) == 2 and nodes[0] != nodes[1]:
            return 'pod-to-pod-NN'
    elif test_type == 'nodeIP':
            return 'node-to-node'
    else:
        if nodes is None:
            return 'svc-to-svc-LB'
        elif len(nodes) == 1:
            return 'svc-to-svc-MN'
        elif len(nodes) == 2 and nodes[0] == nodes[1]:
            return 'svc-to-svc-LB'
        elif len(nodes) == 2 and nodes[0] != nodes[1]:
            return 'svc-to-svc-NN'
        
def get_option(version):
    if Decimal(version) >= 3.5 :
        return '-p'
    else:
        return '-v'


def run_tests(args, inventory_vars, sender_host, receiver_host):
    test_playbook = set_playbook(args.test_type)
    master_host = args.test_master
    nettest = NetworkTest(test_playbook)
    nettest.add_sender(sender_host)
    nettest.add_receiver(receiver_host)
    nettest.add_master(master_host)
    nettest.set_inventory_vars(inventory_vars)
    nettest.run()


def main():
    args = parse_args()

    pbench_remotes = set_pbench_remotes(args.test_master, args.test_nodes)
    pbench_base_label = set_pbench_label(args.test_type, args.test_nodes)

    sender_region = set_sender_region(args.test_master, args.test_nodes)
    receiver_region = set_receiver_region(args.test_master, args.test_nodes)
    sender_host = set_sender(args.test_master, args.test_nodes)
    receiver_host = set_receiver(args.test_master, args.test_nodes)    

    if args.test_type != 'nodeIP':
        oc_process_option = get_option(args.os_version);
        for pod_number in args.pod_numbers:
            pbench_label = '{0}_PODS_{1}'.format(pbench_base_label, pod_number)

            inventory_vars = {'sender_region': sender_region,
                              'receiver_region': receiver_region,
                              'uperf_pod_number': pod_number,
                              'tcp_tests': args.tcp_tests,
                              'udp_tests': args.udp_tests,
                              'msg_sizes': args.msg_sizes,
                              'samples': args.total_samples, 
                              'oc_process_option': oc_process_option,
                              'pbench_label': pbench_label,
                              'pbench_remotes': pbench_remotes}
            run_tests(args, inventory_vars, sender_host, receiver_host)
    else:
            inventory_vars = {'sender_host': sender_host,
                              'receiver_host': receiver_host,
                              'pbench_label': pbench_base_label,
                              'pbench_remotes': pbench_remotes}
            run_tests(args, inventory_vars, sender_host, receiver_host)


if __name__ == '__main__':
    main()
