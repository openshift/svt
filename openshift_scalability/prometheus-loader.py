#!/usr/bin/python
# -*- coding: utf-8 -*-
"""
An loader tool to simulate grafana dashboard queries against prometheus.

Usage:
python prometheusLoader.py -f ./qs.txt -i 20 -t 50 -p 15  > /dev/null 2>&1 &

Log:
/tmp/prometheus_loader.log
"""
import logging
import os
import requests
import random
import time
import argparse
from requests.utils import quote
from concurrent.futures import ThreadPoolExecutor

time_pattern = "YYYY-MM-DD HH:MM:SS.mmm"
log_file = "/tmp/prometheus_loader.log"
log_level = "DEBUG"
log_format = None


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-f',
                        '--file',
                        required=True,
                        dest='file',
                        help='queries file')

    parser.add_argument('-t',
                        '--threads',
                        required=True,
                        type=int,
                        dest='threads',
                        help='simultaneously requests')
    parser.add_argument('-i',
                        '--interval',
                        type=int,
                        required=True,
                        dest='interval',
                        help='sleep interval for each block iteration in sec')

    parser.add_argument('-p',
                        '--period',
                        type=int,
                        required=True,
                        dest='period',
                        help='a time period for query in min')

    return parser.parse_args()


class PrometheusLoader(object):
    def __init__(self, file, threads=30, period=30):
        # args
        self.queries_file = file
        self.threads = threads
        self.period = period
        self.queries = []
        self.token = None
        self.promethues_server = None
        self.executor = ThreadPoolExecutor(max_workers=threads)
        self.headers = None
        self.log = None
        self.log_level = log_level
        self.log_format = "%(asctime)s - %(levelname)s - %(message)s"
        self.log_file = log_file
        self.pattern = time_pattern

        self.logger()
        self.read_queries_from_file()
        self.get_prometheus_info()

    def logger(self):
        try:
            logging.basicConfig(filename=self.log_file, filemode='w',
                                level='DEBUG', format=self.log_format)
            self.log = logging.getLogger(self.log_file)
            self.log.info('starting')
        except Exception as e:
            self.log.error('failed to start log {0} - {1}'.format(
                self.log_file, e))

    def read_queries_from_file(self):
        """
        read queries from file and qute it as urlencoded
        """
        with open(self.queries_file, 'r') as f:
            for line in f:
                self.queries.append(quote(line))

    def get_prometheus_info(self):
        ''' get token and route for prometeus '''
        self.token = 'Bearer ' + os.popen('oc sa get-token prometheus-k8s'
                                          ' -n openshift-monitoring'
                                          ).read()
        self.headers = {'Authorization': self.token}
        self.promethues_server = os.popen("oc get route prometheus-k8s"
                                          " -n openshift-monitoring "
                                          " |grep prometheus |awk '{print $2}'"
                                          ).read().rstrip()

    def generate_req(self):
        ''' gernerate query as http format '''
        time_from = os.popen('date "+%s" -d "{0} min ago"'.format(
                                self.period)).read().rstrip()
        time_now = os.popen('date "+%s"').read().rstrip()
        query = self.queries[random.randint(1, len(self.queries) - 1)]
        return "https://{0}/api/v1/query_range?query={1}&start={2}&end={3}" \
            "&step=1".format(self.promethues_server,
                             query,
                             time_from,
                             time_now)

    def request(self, req):
        ''' fire http request '''
        try:
            res = requests.get(req, verify=False, headers=self.headers)
        except Exception as e:
            self.log.error('bad request {0} response {1}'.format(req, res))
        if res.status_code is not 200 or len(res.text) == 0:
            self.log.error('bad request {0} response {1}'.format(req, res))
        self.log.debug('duration:{0} {1}'.format(res.elapsed.total_seconds(), req))        

    def run_loader(self):
        ''' fire http requests simultaneously in threads batch '''
        for i in range(self.threads):
            self.executor.submit(self.request, self.generate_req())

if __name__ == "__main__":
    args = parse_args()
    p = PrometheusLoader(args.file, args.threads, args.period)
    while True:
        p.run_loader()
        time.sleep(args.interval)
