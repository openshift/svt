#!/usr/bin/env python

import time
import sys
import ocp_utils 

def delete_all_namespaces(job):
    # make sure all namespaces are gone
    print("job type " + str(job))
    if job.lower() == "pod-density":
        job = "node-density"
    ocp_utils.run("oc delete ns --wait=false -l kube-burner-job=" + job)
    wait_for_all_deleted_ns(job)

def wait_for_all_deleted_ns(job, wait_num=300):
    counter = 0
    ns_left = 1000  # starting at random high number
    while int(ns_left) > 0:
        ns_left = ocp_utils.run("oc get ns --no-headers | grep Terminating | wc -l")
        ns_left = ns_left.strip()
        print(ns_left + " namespaces are left to still terminate")
        if counter > wait_num:
            print("Namespaces created by kube burner job " + job + " still have not terminated properly")
            return 1
        counter += 1
        print("waiting 10 seconds and repolling")
        time.sleep(10)
    ocp_utils.run("oc get ns")
    return 0

# total arguments
n = len(sys.argv)
print("Total arguments passed:", n)

job=sys.argv[1]

delete_all_namespaces(job)