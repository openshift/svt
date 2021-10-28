import sys
import time
from azure.mgmt.compute import ComputeManagementClient
from azure.identity import DefaultAzureCredential
import yaml
import logging


class azure_node_scenarios():

    def __init__(self, az_account):
        credentials = DefaultAzureCredential()
        logging.info("credential " + str(credentials))

        az_account_yaml = yaml.safe_load(az_account)
        subscription_id = az_account_yaml[0]['id']
        self.compute_client = ComputeManagementClient(credentials, subscription_id)

    # Node scenario to start the node
    def node_start_scenario(self, node):
        try:
            logging.info("Starting node_start_scenario injection")
            resource_group = self.get_instance_id(node)
            logging.info("Starting the node %s with instance ID: %s " % (node, resource_group))
            self.start_instances(resource_group, node)
            self.wait_until_running(resource_group, node, 80)
            logging.info("Node with instance ID: %s is in running state" % node)
            logging.info("node_start_scenario has been successfully injected!")
        except Exception as e:
            logging.error("Failed to start node instance. Encountered following "
                          "exception: %s. Test Failed" % (e))
            logging.error("node_start_scenario injection failed!")
            sys.exit(1)

    # Node scenario to stop the node
    def node_stop_scenario(self, node):

        try:
            logging.info("Starting node_stop_scenario injection")
            resource_group = self.get_instance_id(node)
            logging.info("Stopping the node %s with instance ID: %s " % (node, resource_group))
            self.stop_instances(resource_group, node)
            self.wait_until_stopped(resource_group, node, 80)
            logging.info("Node with instance ID: %s is in stopped state" % node)
        except Exception as e:
            logging.error("Failed to stop node instance. Encountered following exception: %s. "
                          "Test Failed" % e)
            logging.error("node_stop_scenario injection failed!")
            sys.exit(1)

    # Get the instance ID of the node
    def get_instance_id(self, node_name):
        vm_list = self.compute_client.virtual_machines.list_all()
        for vm in vm_list:
            array = vm.id.split("/")
            resource_group = array[4]
            vm_name = array[-1]
            if node_name == vm_name:
                return resource_group
        logging.error("Couldn't find vm with name " + str(node_name))

    # Start the node instance
    def start_instances(self, group_name, vm_name):
        self.compute_client.virtual_machines.begin_start(group_name, vm_name)

    # Stop the node instance
    def stop_instances(self, group_name, vm_name):
        self.compute_client.virtual_machines.begin_power_off(group_name, vm_name)

    def get_vm_status(self, resource_group, vm_name):
        statuses = self.compute_client.virtual_machines.instance_view(resource_group, vm_name) \
            .statuses
        status = len(statuses) >= 2 and statuses[1]
        return status

    # Wait until the node instance is running
    def wait_until_running(self, resource_group, vm_name, timeout):
        time_counter = 0
        status = self.get_vm_status(resource_group, vm_name)
        while status and status.code != 'PowerState/running':
            status = self.get_vm_status(resource_group, vm_name)
            logging.info("Vm %s is still not running, sleeping for 5 seconds" % vm_name)
            time.sleep(5)
            time_counter += 5
            if time_counter >= timeout:
                logging.info("Vm %s is still not ready in allotted time" % vm_name)
                break

    # Wait until the node instance is stopped
    def wait_until_stopped(self, resource_group, vm_name, timeout):
        time_counter = 0
        status = self.get_vm_status(resource_group, vm_name)
        while status and status.code != 'PowerState/stopped':
            status = self.get_vm_status(resource_group, vm_name)
            logging.info("Vm %s is still stopping, sleeping for 5 seconds" % vm_name)
            time.sleep(5)
            time_counter += 5
            if time_counter >= timeout:
                logging.info("Vm %s is still not stopped in allotted time" % vm_name)
                break