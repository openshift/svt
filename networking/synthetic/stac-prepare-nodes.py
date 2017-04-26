import ansible.runner
import json
import argparse
import subprocess
import sys

from ansible import playbook
from ansible.inventory.host import Host
from ansible.inventory.group import Group
from ansible.inventory import Inventory
from ansible.callbacks import AggregateStats
from ansible.callbacks import PlaybookCallbacks
from ansible.callbacks import PlaybookRunnerCallbacks
from ansible import utils


class NetworkTest(object):
    def __init__(self, playbook):
        self.inventory = Inventory(host_list=[])
        self.playbook = playbook
 
        self.stac_nodes_group = Group(name='stac_nodes')
        self.inventory.add_group(self.stac_nodes_group)
 
        self.inv_vars = dict()

    def set_inventory_vars(self, inv_vars):
        self.inv_vars.update(inv_vars)

    def add_stac_node(self, node):
        stac_node = Host(name=node)
        self.stac_nodes_group.add_host(stac_node)

    def run(self):
        stats = AggregateStats()
        playbook_cb = PlaybookCallbacks(verbose=utils.VERBOSITY)
        runner_cb = PlaybookRunnerCallbacks(stats, verbose=utils.VERBOSITY)

        pb = playbook.PlayBook(playbook=self.playbook,
                               stats=stats,
                               callbacks=playbook_cb,
                               runner_callbacks=runner_cb,
                               inventory=self.inventory,
                               extra_vars=self.inv_vars,
                               check=False)

        pr = pb.run()

        print json.dumps(pr, sort_keys=True, indent=4, separators=(',', ': '))


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

    return parser.parse_args()


def main():
    args = parse_args()
    nettest = NetworkTest('stac-test.yaml')
    for node in args.nodes:
        import pdb; pdb.set_trace()
    	patch_node_oir(args.api_server_url, node)
    	nettest.add_stac_node(node)
    inventory_vars = {'iface_name': args.iface_name}
 
    nettest.set_inventory_vars(inventory_vars)

    nettest.run()


if __name__ == '__main__':
    main()
