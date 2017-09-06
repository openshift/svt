from optparse import OptionParser
import subprocess
import random
import re
import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning
import json
import time

def run(cmd,config=""):

    if config:
        cmd = "KUBECONFIG=" + config + " " + cmd
    result = subprocess.check_output(cmd,stderr=subprocess.STDOUT,shell=True)
    return result

def all_pods(prefix):
    raw_pods = run("oc get pods --all-namespaces -o jsonpath=\'{range .items[*]}{.metadata.namespace} {.metadata.name} {.metadata.uid} {.spec.containers[0].name}$$${end}\' | grep " + prefix).split("$$$")
    pods=[];
    for pod in raw_pods:
        current_pod={}
        pod_props = pod.split()
        if len(pod_props) == 4:
            current_pod["namespace"] = pod_props[0]
            current_pod["name"] = pod_props[1]
            current_pod["uid"] = pod_props[2]
            current_pod["containername"] = pod_props[3]
            pods.append(current_pod)
    return pods

def test_pod_metrics(pod, hawkular_host, bearer, start_time, bucket_duration):

    headers = {'Authorization':"Bearer " + bearer, 'Hawkular-tenant': pod["namespace"]}
    url = "https://" + hawkular_host + \
          "/hawkular/metrics/gauges/" + pod["containername"] + "%2F" + pod["uid"] + "%2Fmemory%2Fusage/data" + \
          "?bucketDuration=" + bucket_duration + "&start=" + start_time
    response = requests.get(url, headers=headers, verify=False)
    if response.status_code == 200:
        results = json.loads(response.text)
        empty = 0
        non_empty = 0
        for result in results:
            if result["empty"] == True:
                empty += 1
            else:
                non_empty +=1
        print "Test of metrics for: " + pod["namespace"] + "." + pod["name"] + " found empty: " + str(empty) + ", not empty: " + str(non_empty)

    else:
        print "Metrics GET to " + url + " failed with status code: " + str(response.status_code)
        print "Headers: " + str(headers)



if __name__ ==  "__main__":

    parser = OptionParser()
    parser.add_option("-B", "--bearer", dest="bearer",
                     help="Bearer token")
    parser.add_option("-p", "--prefix", dest="prefix", help="Project prefix")
    parser.add_option("-H", "--hostname", dest="hostname", help="Hawkular hostname")
    parser.add_option("-s", "--start", dest="start", help="start time")
    parser.add_option("-d", "--duration", dest="duration", help="bucket duration")
    parser.add_option("-i", "--interval", dest="interval", type="int", default=30, help="interval to sleep between checks")
    parser.add_option("-b", "--batch", dest="batch", type="int", default=1,
                      help="batch size to test each interval")

    (options, args) = parser.parse_args()
    requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

    print "Loading all pods - may take a minute..."
    pods = all_pods(options.prefix)

    while True:
        for i in range(0,options.batch):
          pod_to_test = random.choice(pods)
          test_pod_metrics(pod_to_test, options.hostname, options.bearer, options.start, options.duration)
        time.sleep(options.interval)




