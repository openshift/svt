from invoke_command import run_cmd
from start_clouds.aws_node_scenarios import aws_node_scenarios
from start_clouds.gcp_node_scenarios import gcp_node_scenarios
from start_clouds.az_node_scenarios import azure_node_scenarios
import sys
import time
from kubernetes import client, config
import os
import yaml
import optparse
import pyfiglet
import logging

def initialize_clients(kubeconfig_path):
    global cli
    config.load_kube_config(kubeconfig_path)
    cli = client.CoreV1Api()


# List nodes in the cluster
def list_nodes(label_selector):
    nodes = []
    try:
        ret = cli.list_node(pretty=True, label_selector=label_selector)
    except Exception as e:
        logging.info("Exception when calling CoreV1Api->list_node: %s\n" % e)
        return []
    for node in ret.items:
        nodes.append(node.metadata.name)
    return nodes


def get_node_status(node):
    try:
        node_info = cli.read_node_status(node, pretty=True)
    except Exception as e:
        logging.info("Exception when calling \
                       CoreV1Api->read_node_status: %s\n" % e)
    for condition in node_info.status.conditions:
        if condition.type == "Ready":
            return condition.status


def wait_for_all_nodes_ready(node_list):
    while len(node_list) > 0:
        csrs = approve_crs()
        logging.info('node list ' + str(node_list))
        for node in node_list:
            node_status = get_node_status(node)
            logging.info("node status " + str(node_status) + str(node) + str(type(node)))
            if str(node_status) == "True":
                node_list.remove(node)
                continue
        time.sleep(3)


def calc_time(timestr):
    tlist = timestr.split()
    logging.info('t list ' + str(tlist))
    if tlist[1] == "s":
        return int(tlist[0])
    elif tlist[1] == "min":
        return int(tlist[0]) * 60
    elif tlist[1] == "ms":
        return int(tlist[0]) / 1000
    elif tlist[1] == "hr":
        return int(tlist[0]) * 3600
    else:
        logging.info("Invalid delay in rate_limit Exiting ........")
        sys.exit(1)


def shutdown_via_ssh(node_list, ssh_file):

    if ssh_file != "":
        ssh_param = " -i " + ssh_file
    else:
        ssh_param = ""
    for node in node_list:
        logging.info("==== Shutdown " + str(node) + " ====")
        run_cmd("ssh " + ssh_param + "core@" + node + " sudo shutdown - h")


def approve_crs():
    run_cmd("oc get csr | grep Pending | cut -f1 -d" " | while read i; do oc adm certificate approve $i; done")


def wait_for_ready_status(node, timeout):
    run_cmd("kubectl wait --for=condition=Ready "
            "node/" + node + " --timeout=" + str(timeout) + "s")


def backup_etcd(master_node):

    run_cmd("oc debug node/" + master_node +" -- chroot /host /usr/local/bin/cluster-backup.sh /home/core/assets/backup")



# Main function
def main(cfg):
    # Parse and read the config
    if os.path.isfile(cfg):
        with open(cfg, 'r') as f:
            config = yaml.full_load(f)
        config = config["shutdown"][0]
        cloud_type = config['cloud_type']
        kubeconfig_path = config.get("kubeconfig_path", "~/.kube/config")

        shutdown_master_num = config.get("shutdown_master_num", "all")
        shutdown_worker_num = config.get("shutdown_worker_num", "all")
        shutdown_infra_num = config.get("shutdown_infra_num", "all")

        ssh_file = config.get("ssh_file", "")

        initialize_clients(kubeconfig_path)
        downtime = calc_time(config.get("downtime", "300 s"))

        masters = list_nodes("node-role.kubernetes.io/master")
        backup_etcd(masters[1])

        if shutdown_master_num != "all":
            new_master_list = []
            for i in range(int(shutdown_master_num)):
                new_master_list.append(masters[i])
            masters = new_master_list

        workers = list_nodes("node-role.kubernetes.io/worker=,node-role.kubernetes.io/infra!=")
        if shutdown_worker_num != "all":
            new_worker_list = []
            for i in range(int(shutdown_worker_num)):
                new_worker_list.append(workers[i])
            workers = new_worker_list

        infras = list_nodes("node-role.kubernetes.io/infra")

        if shutdown_infra_num != "all":
            new_infra_list = []
            for i in range(int(shutdown_infra_num)):
                new_infra_list.append(infras[i])
            infras = new_infra_list

        node_list = workers + infras + masters
        logging.info('node list ' + str(node_list))

        if cloud_type == "aws":
            aws = aws_node_scenarios()
            for node in node_list:
                logging.info('stop node ' + str(node))
                aws_node_scenarios.node_stop_scenario(aws, node)

        elif cloud_type == "azure" or cloud_type == "az":
            logging.info("azure")
            az_account = run_cmd("az account list -o yaml")
            az = azure_node_scenarios(az_account)
            for node in node_list:
                logging.info('stop node ' + str(node))
                azure_node_scenarios.node_stop_scenario(az, node)
        elif cloud_type == "gcp":
            logging.info('gcp')
            project = run_cmd('gcloud config get-value project').split('/n')[0].strip()
            gcp = gcp_node_scenarios(project)

            for node in node_list:
                logging.info('stop node ' + str(node))
                gcp_node_scenarios.node_stop_scenario(gcp, node)
        else:
            logging.info("Shutting down using ssh")
            shutdown_via_ssh(node_list, ssh_file)

        # wait period
        time.sleep(downtime)

        # restart cluster
        # start nodes based on cloud provider
        if cloud_type == "aws":
            for node in node_list:
                logging.info('start node ' + str(node))
                aws_node_scenarios.node_start_scenario(aws, node)

        elif cloud_type == "azure" or cloud_type == "az":

            for node in node_list:
                logging.info('start node ' + str(node))
                azure_node_scenarios.node_start_scenario(az, node)

        elif cloud_type == "gcp":
            for node in node_list:
                logging.info('start node ' + str(node))
                gcp_node_scenarios.node_start_scenario(gcp, node)
        else:
            logging.info("Cloud type " + str(cloud_type) + " is not supported ")
            sys.exit(1)

        wait_for_all_nodes_ready(masters)

        wait_for_all_nodes_ready(workers)

        wait_for_all_nodes_ready(infras)

        cluster_operators = run_cmd("oc get co")

        run_cmd("oc get nodes")

if __name__ == "__main__":
    # Initialize the parser to read the config
    parser = optparse.OptionParser()
    parser.add_option(
        "-c", "--config",
        dest="cfg",
        help="config location",
        default="config/config.yaml",
    )
    (options, args) = parser.parse_args()
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.FileHandler("shutdown.report", mode='w'),
            logging.StreamHandler()
        ]
    )
    if (options.cfg is None):
        logging.error("Please check if you have passed the config")
        sys.exit(1)
    else:
        main(options.cfg)
