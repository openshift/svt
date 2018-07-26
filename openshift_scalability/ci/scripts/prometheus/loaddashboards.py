#!/usr/bin/python
# -*- coding: utf-8 -*-
"""
The following module will load and parse the dashboard-definitions from
cluster-monitoring-operator project and retrieve dashboards object that include
a set of dashboard and queries dictionaries.
"""
import yaml
import json
import os
import argparse
from requests.utils import quote


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-g',
                        '--gitrepo',
                        type=str,
                        required=False,
                        default='https://raw.githubusercontent.com/openshift/cluster-monitoring-operator/master/assets/grafana/dashboard-definitions.yaml',
                        dest='gitrepo',
                        help='gitrepo')
    parser.add_argument('-p',
                        '--print',
                        type=str,
                        required=False,
                        dest='printit',
                        help='print results')
    return parser.parse_args()

class Dashboards(object):
    def __init__(self, file):
        self.dashboards = []

        if 'http' in file:
            import urllib
            sock = urllib.urlopen(file)
            htmlSource = sock.read()
            sock.close()
            self.yaml = yaml.load(htmlSource)
        else:
            self.yaml = self.load_yaml(file)

        self.scan_dashboards()

    def load_yaml(self, f):
        with open(f, 'r') as y:
            return yaml.load(y)

    def scan_dashboards(self):
        for item in self.yaml.get('items'):
            dashboard = {}
            dashboard['name'] = item['data'].keys()[0]
            dashboard['queries'] = self.scan_queries(json.loads(item['data'].values()[0]))
            self.dashboards.append(dashboard)

    def scan_queries(self, jsondata):
        exprs = []
        for raw in jsondata['rows']:
            for panel in raw['panels']:
                for target in panel['targets']:
                    t = target['expr']
                    # TODO: // make sure to have templating values
                    if 'node=\"$node\"' in t:
                        t.replace('node=\"$node\"','node=~\"^.*\"')
                    if 'namespace=\"$namespace\"' in t:
                        t.replace('namespace=\"$namespace\"','namespace=~\"^.*\"')
                    if 'pod_name=\"$pod\"' in t:
                        t.replace('pod_name=\"$pod\"','pod_name=~\"^.*\"')
                    if 'instance=\"$instance\"' in t:
                        t.replace('instance=\"$instance\"','instance=~\"^.*\"')
                    if 'statefulset=\"$statefulset\"' in t:
                        t.replace('statefulset=\"$statefulset\"','statefulset=~\"^.*\"')
                    exprs.append(quote(q))
        return exprs

    def get_dashboards(self):
        return self.dashboards
