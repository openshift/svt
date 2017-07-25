#!/usr/bin/env python
from optparse import OptionParser
import logging
import subprocess
import os
from concurrent.futures import ThreadPoolExecutor
from string import Template
import time
import json
import boto3
import sys


class PVC(object):
    def __init__(self, name, creation_timestamp=None, is_bound=False,
                 volume_name=None, aws_volume_create_time=None):
        self.name = name
        self.creation_timestamp = creation_timestamp
        self.is_bound = is_bound
        self.volume_name = volume_name
        self.aws_volume_create_time = aws_volume_create_time

    def __str__(self):
        return "{name: %s, creation_timestamp: %s. is_bound: %s, " \
               "volume_name: %s, aws_volume_create_time: %s}" \
               % (self.name, self.creation_timestamp,
                  self.is_bound, self.volume_name, self.aws_volume_create_time)


def run(cmd, config=""):
    if config:
        cmd = "KUBECONFIG=" + config + " " + cmd
    try:
        logger.info('command: %s', cmd)
        return subprocess.check_output(cmd, stderr=subprocess.STDOUT,
                                       shell=True)
    except subprocess.CalledProcessError as error:
        return error.output


def init_logger(logger):
    logger.setLevel(logging.DEBUG)
    fh = logging.FileHandler('/tmp/pvc_bound_test.log')
    fh.setLevel(logging.DEBUG)
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(threadName)s '
                                  '- %(levelname)s - %(message)s')
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)
    logger.addHandler(fh)
    logger.addHandler(ch)


def bound(pvc):
    result = run("oc get pvc " + pvc.name + " -o json")
    try:
        json_data = json.loads(result)
        pvc.is_bound = ('status' in json_data) and \
                       ('phase' in json_data['status']) and \
                       ('Bound' == json_data['status']['phase'])
        if ('metadata' in json_data) and \
                ('creationTimestamp' in json_data['metadata']):
            pvc.creation_timestamp = json_data['metadata']['creationTimestamp']
        if ('spec' in json_data) and ('volumeName' in json_data['spec']):
            pvc.volume_name = json_data['spec']['volumeName']
    except ValueError as error:
        logger.error('error occurred when parsing json from ' + result)
        return False, None


def set_volume_create_time(pvc):
    global client
    logger.info(pvc.volume_name)
    response = client.describe_volumes(
        Filters=[
            {
                'Name': 'tag-key',
                'Values': [
                    'Name',
                ],
            },
            {
                'Name': 'tag-value',
                'Values': [
                    pvc.volume_name,
                ],
            },
        ],
    )
    if 200 == response['ResponseMetadata']['HTTPStatusCode'] and \
                    'Volumes' in response.keys() and \
            isinstance(response['Volumes'], list):
        pvc.aws_volume_create_time = response['Volumes'][0]['CreateTime']
    else:
        logger.error("cannot parse response: %s" % response)



def check(pvc):
    test = 0
    min = 2
    timeout = time.time() + 60 * min   # 2 minutes from now
    start_time = time.time()
    while not pvc.is_bound:
        if test == 5 or time.time() > timeout:
            break
        bound(pvc)
        if pvc.is_bound:
            end_time = time.time()
            break
        logger.info('test (%d) for pvc: %s' % (test, pvc.name))
        time.sleep(10)
        test = test + 1
    if pvc.is_bound:
        set_volume_create_time(pvc)
        logger.info('pvc =%s= is bound in %d (s)' %
                    (pvc, end_time - start_time))
    else:
        logger.error('pvc: %s is NOT bound in %d min(s)' % (pvc.name, min))


def create_pvc(file):
    global project
    result = run("oc create -f \"" + file + "\"")
    if result.lower().startswith("error:"):
        logger.error(result)
        sys.exit(1)
    if 'Error from server (AlreadyExists):' in result:
        logger.error("project has pvc already, please 'oc delete project %s'" %
                     project)
        sys.exit(1)


def pvc_task(i, data):
    global global_config
    name = "pvc-ebs-" + str(i)
    output_path = "/tmp/pvc_ebs_" + str(i) + ".yaml"
    with open(output_path, "w") as out_file:
        out_file.write(Template(data).
                       substitute(name=name, size=str(global_config["size"])))
    create_pvc(output_path)
    check(PVC(name))


def check_project():
    result = run("oc project")
    logger.info(result)
    global project
    if (project not in result) or ('error:' in result):
        logger.error("currently not using desired project %s" % project)
        logger.error("'oc project %s' or 'oc new-project %s'" % (project, project))
        sys.exit(1)


def main():
    global global_config
    parser = OptionParser()
    parser.add_option("-s", "--size", dest="size", default="1", help="PVC size")
    parser.add_option("-c", "--count", dest="count", default="1",
                      help="PVC count")

    (options, args) = parser.parse_args()
    global_config["size"] = int(options.size)
    global_config["count"] = int(options.count)
    logger.info('size: %d; count: %d' % (global_config["size"],
                                         global_config["count"]))
    check_project()
    with open(os.path.join(
                    os.path.dirname(os.path.realpath(__file__)) + '/../content',
            "pvc_ebs.yaml"), 'r') as my_file:
        data = my_file.read()
        results = []
        with ThreadPoolExecutor(max_workers=10) as executor:
            for i in range(0, global_config["count"]):
                results.append(executor.submit(pvc_task, i, data))


if __name__ == "__main__":
    logger = logging.getLogger('pvc_bound_test')
    init_logger(logger)
    global_config = {}
    client = boto3.client('ec2')
    project = "project-test-pvc-bound"
    try:
        main()
    except Exception as e:
        logger.error(e)
