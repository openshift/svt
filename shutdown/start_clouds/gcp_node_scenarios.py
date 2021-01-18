import sys
import time
from googleapiclient import discovery
from oauth2client.client import GoogleCredentials
import logging

class gcp_node_scenarios():

    def __init__(self, project):
        self.project = project
        logging.info("project " + str(self.project) + "!")
        credentials = GoogleCredentials.get_application_default()
        self.client = discovery.build('compute', 'v1', credentials=credentials,
                                      cache_discovery=False)

    # Node scenario to stop the node
    def node_stop_scenario(self, node):
        logging.info('stop scenario')
        try:
            logging.info("Starting node_stop_scenario injection")
            instance_id, zone = self.get_instance_id(node)
            logging.info("Stopping the node %s with instance ID: %s " % (node, instance_id))
            self.stop_instances(zone, instance_id)
            self.wait_until_stopped(zone, instance_id, 80)
            logging.info("Node with instance ID: %s is in stopped state" % instance_id)
        except Exception as e:
            logging.error("Failed to stop node instance. Encountered following exception: %s. "
                          "Test Failed" % (e))
            logging.error("node_stop_scenario injection failed!")
            sys.exit(1)

    # Node scenario to start the node
    def node_start_scenario(self, node):

        try:
            logging.info("Starting node_start_scenario injection")
            instance_id, zone = self.get_instance_id(node)
            logging.info("Starting the node %s with instance ID: %s " % (node, instance_id))
            self.start_instances(zone, instance_id)
            self.wait_until_running(zone, instance_id, 80)
            logging.info("Node with instance ID: %s is in running state" % instance_id)
            logging.info("node_start_scenario has been successfully injected!")
        except Exception as e:
            logging.error("Failed to start node instance. Encountered following "
                          "exception: %s. Test Failed" % (e))
            logging.error("node_start_scenario injection failed!")
            sys.exit(1)

    # Get the instance ID of the node
    def get_instance_id(self, node):
        zone_request = self.client.zones().list(project=self.project)
        while zone_request is not None:
            zone_response = zone_request.execute()
            for zone in zone_response['items']:
                instances_request = self.client.instances().list(project=self.project,
                                                                 zone=zone['name'])
                while instances_request is not None:
                    instance_response = instances_request.execute()
                    if "items" in instance_response.keys():
                        for instance in instance_response['items']:
                            if instance['name'] in node:
                                return instance['name'], zone['name']
                    instances_request = self.client.zones().list_next(
                        previous_request=instances_request,
                        previous_response=instance_response)
            zone_request = self.client.zones().list_next(previous_request=zone_request,
                                                         previous_response=zone_response)
        logging.info('no instances ')

    # Start the node instance
    def start_instances(self, zone, instance_id):
        self.client.instances().start(project=self.project, zone=zone, instance=instance_id) \
            .execute()

    # Stop the node instance
    def stop_instances(self, zone, instance_id):
        self.client.instances().stop(project=self.project, zone=zone, instance=instance_id) \
            .execute()
    
    # Get instance status
    def get_instance_status(self, zone, instance_id, expected_status, timeout):
        # statuses: PROVISIONING, STAGING, RUNNING, STOPPING, SUSPENDING, SUSPENDED, REPAIRING,
        # and TERMINATED.
        i = 0
        sleeper = 5
        while i <= timeout:
            instStatus = self.client.instances().get(project=self.project, zone=zone,
                                                     instance=instance_id).execute()
            logging.info("Status of vm " + str(instStatus['status']))
            if instStatus['status'] == expected_status:
                return True
            time.sleep(sleeper)
            i += sleeper
        logging.info("Status of %s was not %s in a")

    # Wait until the node instance is running
    def wait_until_running(self, zone, instance_id, timeout):
        self.get_instance_status(zone, instance_id, 'RUNNING', timeout)

    # Wait until the node instance is stopped
    def wait_until_stopped(self, zone, instance_id, timeout):
        self.get_instance_status(zone, instance_id, 'TERMINATED', timeout)