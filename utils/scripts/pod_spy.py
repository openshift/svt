import subprocess
import re
import time
import sys
import logging

# regex to parse oc get pods -o wide lines
# cakephp-mysql-example-5      cakephp-mysql-example-1-build   1/1     Running     0          54s     10.128.2.27    ip-10-0-173-169.us-west-2.compute.internal   <none>
pod_entry_regex = re.compile("(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?).*")
logger = logging.getLogger("pod_spy")



def oc(cmd, config=""):
    cmd = "oc " + cmd
    rc = 0
    result = ""
    if config:
        cmd = "KUBECONFIG=" + config + " " + cmd
    try:
        result = subprocess.check_output(cmd, stderr=subprocess.STDOUT, shell=True)
    except subprocess.CalledProcessError as cpe:
        rc = cpe.returncode
        result = cpe.output
    
    string_result = result.decode("utf-8")
    return string_result, rc

def init_logger(my_logger): 
    my_logger.setLevel(logging.INFO)
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    my_logger.addHandler(ch)

# Get info for all pods and store each piece of info in a dict for comparison with subsequent gets.
# Key is the fully qualified pod name formatted as namespace.pod_name

def get_pod_info():
    all_pods={}
    get_pods_out,rc = oc("get pods --all-namespaces --no-headers -o wide")
    if rc == 0 :
        pod_info_list = get_pods_out.split('\n')
        for pod_info in pod_info_list:
            this_pod = {}
            pod_entry_parse = pod_entry_regex.search(pod_info)
            if pod_entry_parse:
                this_pod["namespace"] = pod_entry_parse.group(1)
                this_pod["name"] = pod_entry_parse.group(2)
                this_pod["ready"] = pod_entry_parse.group(3)
                this_pod["status"] = pod_entry_parse.group(4)
                this_pod["restarts"] = pod_entry_parse.group(5)
                this_pod["age"] = pod_entry_parse.group(6)
                this_pod["ip"] = pod_entry_parse.group(7)
                this_pod["node"] = pod_entry_parse.group(8)
                fq_pod_name = this_pod["namespace"] + "." + this_pod["name"]

                all_pods[fq_pod_name] = this_pod
            elif pod_info != '':       
                logger.error("Could not parse oc get pods output: " + pod_info)
    else:
        logger.error("oc get pods failed with rc: " + str(rc))

    return all_pods

#Check for additions/deletions/field changes

def compare_pod_info(old, new):
    keys = ["namespace", "name", "ready", "status", "restarts", "age", "ip", "node"]
    for pod in new:
        # new pods
        if not pod in old:
            logger.info("NEW: " + pod)
        else:
            for key in keys:
                if key != "age" and new[pod][key] != old[pod][key]:
                    logger.info("CHANGE: " + pod + " key: " + key + " old: " + old[pod][key] + " new: " + new[pod][key])
                elif key == "age":
                    pass
    # deleted pods
    for pod in old:
        if not pod in new:
            logger.info("GONE: " + pod)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sleep_time = 15
    else:
        sleep_time = int(sys.argv[1])
    init_logger(logger)
    new_pod_info = {}
    old_pod_info = {}
    old_pod_info = get_pod_info()
    while True:
        new_pod_info = get_pod_info()
        compare_pod_info(old_pod_info, new_pod_info)
        old_pod_info = new_pod_info
        time.sleep(sleep_time)
        
