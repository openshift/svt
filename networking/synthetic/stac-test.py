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

class NetworkTest(object):
    def __init__(self, playbook):
        self.inventory = Inventory(host_list=[])
        self.playbook = playbook
        
        self.producer_group = Group(name = 'producer')
        self.inventory.add_group(self.producer_group)
        
        self.consumer_group = Group(name = 'consumer')
        self.inventory.add_group(self.consumer_group)
        
        self.orchestrator_group = Group(name = 'orchestrator')
        self.inventory.add_group(self.orchestrator_group)
        
        self.inv_vars = dict()

        
    def set_inventory_vars(self, inv_vars):
        self.inv_vars.update(inv_vars)


    def add_producer(self, producer):
        producer_host = Host(name = producer)
        self.producer_group.add_host(producer_host)


    def add_consumer(self, consumer):
        consumer_host = Host(name = consumer)
        self.consumer_group.add_host(consumer_host)

        
    def add_orchestrator(self, orchestrator):
        orchestrator_host = Host(name = orchestrator)
        self.orchestrator_group.add_host(orchestrator_host)


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

    parser.add_argument('-o',
                        '--orchestrator',
                        required = True,
                        dest = 'test_orchestrator',
                        help = 'OpenShift orchestrator node')
    
    parser.add_argument('-p',
                        '--producer',
                        required = True,
                        dest = 'test_producer',
                        help = 'OpenShift node IP for running stac-N1 producer')

    parser.add_argument('-c',
                        '--consumer',
                        required = True,
                        dest = 'test_consumer',
                        help = 'OpenShift node IP for running stac-N1 consumer')

    parser.add_argument('-rp',
                        '--stac_repo_path',
                        required = True,
                        dest = 'stac_repo_path',
                        help = 'url to wget stac-N1 repo')

    parser.add_argument('-if',
                        '--iface_name',
                        required = False,
                        dest = 'iface_name',
                        help = 'stac-n1 orchestrator interface name, default:eth0')
        
    parser.add_argument('-f',
                        '--fast_mode',
                        required = False,
                        dest = 'fast_mode',
                        help = 'for a quick check set this to True') 
    
    return parser.parse_args()


def main():
    args = parse_args()
    
    producer_host = args.test_producer
    consumer_host = args.test_consumer
    orchestrator_host = args.test_orchestrator
    
    producer_region = 'producer'
    consumer_region = 'consumer'
    if not args.iface_name:
    	args.iface_name = 'eth0'
    inventory_vars = { 'producer_region': producer_region,
                       'consumer_region': consumer_region,
                       'producer': producer_host,
                       'consumer': consumer_host,
                       'stac_repo_path': args.stac_repo_path,
 		       'iface_name': args.iface_name,
                       'test_mode_fast': args.fast_mode}
    
    nettest = NetworkTest('stac-test.yaml')

    nettest.add_producer(producer_host)
    nettest.add_consumer(consumer_host)
    nettest.add_orchestrator(orchestrator_host)
    
    nettest.set_inventory_vars(inventory_vars)

    nettest.run()
    

if __name__ == '__main__':
    main()
