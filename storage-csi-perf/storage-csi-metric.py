#!/usr/bin/env python3
import argparse
import elasticsearch
import subprocess
import json
import requests
import urllib3
from datetime import datetime
import math
import uuid
import os
import ast
import ssl
es_server = os.getenv("ES_SERVER")
es_index = os.getenv("ES_INDEX")
def index_result(payload, retry_count=3):
    # Environment vars
    print(f"Indexing documents in {es_index}")
    while retry_count > 0:
        try:
            ssl_ctx = ssl.create_default_context()
            ssl_ctx.check_hostname = False
            ssl_ctx.verify_mode = ssl.CERT_NONE
            es = elasticsearch.Elasticsearch([es_server], send_get_body_as='POST',ssl_context=ssl_ctx, use_ssl=True)
            print("#"*118)
            print("ES Information: \n{}".format(es.info()))
            print("#"*118)
            print()
            es.index(index=es_index, body=payload,doc_type='doc')

            retry_count = 0
        except Exception as e:
            print("Failed Indexing - \n" + str(e.message))
            print("Retrying again to index...")
            retry_count -= 1

'''Getting token to access prometheus api'''
# Invokes a given command and returns the stdout
def invokecmd(command):

    try:
        cmdStdOut = subprocess.check_output(command, shell=True, universal_newlines=True,stdin=subprocess.PIPE, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as exc:
        print("Status: execute {} failure, return code is {}, Error message:\n {}".format(command,exc.returncode,exc.stderr))
        return exc.returncode,exc.stderr
    return 0, cmdStdOut

def get_sa_token():

    returnCode,cmdStdOut = invokecmd('oc create token -n openshift-monitoring prometheus-k8s')

    if returnCode and cmdStdOut.find("unknown command"):
        print("oc create token -n openshift-monitoring prometheus-k8s is unknown command, try another command")
        returnCode, cmdStdOut = invokecmd('oc sa new-token -n openshift-monitoring prometheus-k8s')
        if returnCode:
            print("Fail to get the token for sa  prometheus-k8s, please check")
            exit(1)
    return returnCode,cmdStdOut

def getTimeDuration(start_time, end_time):

    time1 = datetime.fromtimestamp(start_time)
    time2 = datetime.fromtimestamp(end_time)
    #Return how long minutes duration
    return math.ceil((time2 - time1).total_seconds() / 60)


def get_storage_metrics(provider,start_time,end_time,spec_time_duration):
        if start_time >= end_time:
            print("End time must great than start time")
            exit(1)
        returnCode,token = get_sa_token()
        if returnCode:
            print("Fail to get the token for sa prometheus-k8s, please check")
            exit(1)

        returnCode,prometheusURL=invokecmd('oc get route -n openshift-monitoring prometheus-k8s -o jsonpath="{.spec.host}"')
        if returnCode:
             print("Fail to get prometheus URL")
             exit(1)

        #Define variable
        prom_query_api_url=''
        PromQL=''
        StorageMetric=''
        if spec_time_duration:
            timeDuration = getTimeDuration(start_time, end_time)
            #if timeDuration <= 30:
            #   timeDuration=30
            print("#" * 118)
            print("Query storage metric data from {} to {} , time duration is {} minutes".format(datetime.fromtimestamp(start_time),datetime.fromtimestamp(end_time),timeDuration))
            print("#" * 118)
            print()
            PromQueryAPIURL = "https://"+prometheusURL+"/api/v1/query?query="
            PromQL = "histogram_quantile(0.99, sum by (operation_name, le) (rate(storage_operation_duration_seconds_bucket{{volume_plugin=~\".*{}\"}}[{}m])))".format(provider,timeDuration)
            print("-" * 118)
            print(PromQL)
            print("-" * 118)
            StorageMetric=PromQueryAPIURL + PromQL
        else:
            print("#" * 118)
            print("Scratch storage metric data for {} without time duration after loaded upgrade".format(provider))
            print("#" * 118)
            print()
            PromQueryAPIURL = "https://" + prometheusURL + "/api/v1/query?query="
            PromQL = "histogram_quantile(0.99, sum by (operation_name, le) (storage_operation_duration_seconds_bucket{{volume_plugin=~\".*{}\"}}))".format(provider)
            print("-" * 118)
            print(PromQL)
            print("-" * 118)
            StorageMetric = PromQueryAPIURL + PromQL

        #Disable InsecureRequestWarning: Unverified HTTPS request is being made.
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        storage_metrics=requests.post(url=StorageMetric, headers={'Authorization': 'Bearer {}'.format(token)},verify=False).content.decode('utf8', 'ignore')

        storage_metrics_json=json.loads(storage_metrics)
        print("The metrics of storage_operation_duration_seconds_bucket in prometheus:\n{}\n{}".format("-" * 118,storage_metrics_json))
        print("-" * 118)
        print()

        payload={}

        currentTime=datetime.utcnow()
        test_type = os.getenv("WORKLOAD")
        total_workload = os.getenv("TOTAL_WORKLOAD")
        get_timestamp_uuid = os.getenv("UUID")
        cluster_id = os.getenv("CLUSTER_ID", "")
        cluster_name = os.getenv("CLUSTER_NAME", "")
        openshift_version = os.getenv("OPENSHIFT_VERSION", "")
        kubernetes_version = os.getenv("KUBERNETES_VERSION", "")
        network_type = os.getenv("CLUSTER_NETWORK_TYPE", "")
        returnCode,total_workernode=invokecmd("oc get nodes -L node-role.kubernetes.io/worker= --no-headers|wc -l")
        if returnCode:
            print("Fail to get total worker nodes, please check")
            exit(1)
        returnCode,cluster_platform=invokecmd("oc get infrastructure cluster -ojsonpath='{.status.platformStatus.type}'")
        if returnCode:
            print("Fail to get cluster infrastructure, please check")
            exit(1)

        payload["test_type"]=test_type
        payload["total_workload"]=int(total_workload)
        payload["total_workernode"]=int(total_workernode)
        payload["uuid"]=get_timestamp_uuid
        payload["cluster.id"]=cluster_id
        payload["cluster.name"] = cluster_name
        payload["cluster.ocp_version"] = openshift_version
        payload["cluster.kubernetes_version"] = kubernetes_version
        payload["cluster.sdn"] = network_type
        payload["cluster.platform"] = cluster_platform


        results = storage_metrics_json['data']['result']
        for r in results:
            key=r['metric']['operation_name']
            value=float(r['value'][1])
            if math.isnan(value): 
               value=float(0)
            payload[key]=value
        print()
        print("The payload will save to elasticsearch:\n{}\n{}".format("-" * 118,payload))
        print("-" * 118+'\n')
        #save to elasticsearch
        if es_server != "":
           payload["timestamp"] = currentTime
           index_result(payload)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-c",
        "--csi",
        help="CSI provider: ebs.csi.aws.com",
        required=True
    )
    parser.add_argument(
        "-s",
        "--start_time",
        help="Start Time: 1683795707(Linux timestap)",
        required=True,
        type=int,
    )
    parser.add_argument(
        "-e",
        "--end_time",
        help="End Time: 1683796918(Linux timestap)",
        required=True,
        type=int,
    )
    parser.add_argument(
        "-t",
        "--spec_time_duration",
        help="If specify time duration when query storage metric: True or False",
        type=ast.literal_eval,
        dest='spec_time_duration',
        required=True,
    )
    args = parser.parse_args()
    get_storage_metrics(args.csi, int(args.start_time), int(args.end_time),args.spec_time_duration)
