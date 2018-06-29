import argparse
import json
import subprocess
import sys
from collections import namedtuple

from ansible.executor.playbook_executor import PlaybookExecutor
from ansible.inventory import Inventory
from ansible.inventory.group import Group
from ansible.inventory.host import Host
from ansible.parsing.dataloader import DataLoader
from ansible.vars import VariableManager


class NetworkTest(object):
    def __init__(self, playbook):
        self.playbook = playbook
        self.dataloader = DataLoader()
        self.variablemanager = VariableManager()
        self.inventory = Inventory(loader=self.dataloader,
                                   variable_manager=self.variablemanager,
                                   host_list=[])

        self.stac_nodes_group = Group(name='stac_nodes')
        self.inventory.add_group(self.stac_nodes_group)
        self.inv_vars = dict()
        self.options = None

        Options = namedtuple('Options',
                             ['listtags', 'listtasks', 'listhosts', 'syntax',
                              'connection', 'module_path', 'forks',
                              'remote_user', 'private_key_file',
                              'ssh_common_args', 'ssh_extra_args',
                              'sftp_extra_args', 'scp_extra_args', 'become',
                              'become_method', 'become_user', 'verbosity',
                              'check'])

        self.options = Options(listtags=False, listtasks=False, listhosts=False,
                               syntax=False, connection='ssh', module_path=None,
                               forks=100,
                               remote_user=None, private_key_file=None,
                               ssh_common_args=None,
                               ssh_extra_args=None, sftp_extra_args=None,
                               scp_extra_args=None, become=False,
                               become_method=None,
                               become_user=None, verbosity=10, check=False)

    def set_inventory_vars(self, inv_vars):
        self.inv_vars.update(inv_vars)

    def add_stac_node(self, node):
        stac_node = Host(name=node)
        self.stac_nodes_group.add_host(stac_node)

    def run(self):
        passwords = {}
        pbex = PlaybookExecutor(playbooks=[self.playbook],
                                inventory=self.inventory,
                                variable_manager=self.variablemanager,
                                loader=self.dataloader,
                                options=self.options, passwords=passwords)

        results = pbex.run()

        print json.dumps(results, sort_keys=True, indent=4,
                         separators=(',', ': '))


def patch_node_oir(api_server, node):
    cmd = ['sh', './scripts/patch-oir.sh', api_server, node]
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, stdin=subprocess.PIPE)
        out, err = p.communicate()
        if not out:
            print err
            sys.exit()
    except Exception as e:
        print "Failed to patch nodes!!!"
        raise e


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-s',
                        '--api-server-url',
                        required=True,
                        dest='api_server_url',
                        help='api_server_url')

    parser.add_argument('-n',
                        '--nodes',
                        required=True,
                        nargs='*',
                        dest='nodes',
                        help='nodes to be prepared for stac tests')

    parser.add_argument('-i',
                        '--iface-name',
                        required=True,
                        dest='iface_name',
                        help='interace name on nodes through which stac test traffic will run')

    parser.add_argument('-p',
                        '--patch-oir',
                        required=False,
                        dest='patch_oir',
                        help='true or false to patch oir')

    parser.add_argument('-r',
                        '--rhel-repo',
                        required=True,
                        dest='rhel_repo',
                        help='true or false to patch oir')

    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    nettest = NetworkTest('stac-prepare-nodes.yaml')
    for node in args.nodes:
        if args.patch_oir:
            patch_node_oir(args.api_server_url, node)
        nettest.add_stac_node(node)

    inventory_vars = {
        'iface_name': args.iface_name,
        'rhel_repo': args.rhel_repo
    }

    nettest.set_inventory_vars(inventory_vars)

    nettest.run()
    print 'ansible playbook completed reboot your nodes! {0}'.format(args.nodes)
