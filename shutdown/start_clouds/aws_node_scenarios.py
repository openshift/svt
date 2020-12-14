import sys
import boto3
import logging


class aws_node_scenarios():

    def __init__(self):
        self.boto_client = boto3.client('ec2')
        self.boto_instance = boto3.resource('ec2').Instance('id')

    # Get the instance ID of the node
    def get_instance_id(self, node):
        return self.boto_client.describe_instances(
            Filters=[{'Name': 'private-dns-name', 'Values': [node]}]
        )['Reservations'][0]['Instances'][0]['InstanceId']

    # Start the node instance
    def start_instances(self, instance_id):
        self.boto_client.start_instances(
            InstanceIds=[instance_id]
        )

    # Stop the node instance
    def stop_instances(self, instance_id):
        self.boto_client.stop_instances(
            InstanceIds=[instance_id]
        )

    # Wait until the node instance is running
    def wait_until_running(self, instance_id):
        self.boto_instance.wait_until_running(
            InstanceIds=[instance_id]
        )

    # Wait until the node instance is stopped
    def wait_until_stopped(self, instance_id):
        self.boto_instance.wait_until_stopped(
            InstanceIds=[instance_id]
        )

    # Node scenario to start the node
    def node_start_scenario(self, node):
        try:
            logging.info("Starting node_start_scenario injection")
            instance_id = self.get_instance_id(node)
            logging.info("Starting the node %s with instance ID: %s " % (node, instance_id))
            self.start_instances(instance_id)
            
            self.wait_until_running(instance_id)
            logging.info("Node with instance ID: %s is in running state" % (instance_id))
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
            instance_id = self.get_instance_id(node)
            logging.info("Stopping the node %s with instance ID: %s " % (node, instance_id))
            self.stop_instances(instance_id)
            logging.info("stopped instance")
            self.wait_until_stopped(instance_id)
            logging.info("Node with instance ID: %s is in stopped state" % (instance_id))
        except Exception as e:
            logging.error("Failed to stop node instance. Encountered following exception: %s. "
                          "Test Failed" % (e))
            logging.error("node_stop_scenario injection failed!")
            sys.exit(1)