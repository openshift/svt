#!/usr/bin/env python

from optparse import OptionParser
import re

# For an individual pod, check that each message id occurs once.  None missing, no duplicates
def verify(expected,actual) :
    missing = 0
    duplicates = 0

    for i in range(1, expected+1) :
        key = str(i)
        if not key in actual :
            print "MISSING: " + key
            missing += 1
        elif actual[key] > 1 :
            print "DUPLICATE: " + key + ": COUNT=" + str(actual[key])
            duplicates += 1

    if (missing > 0) or (duplicates > 0):
        verdict = "PROBLEM: missing=" + str(missing) + " duplicates=" + str(duplicates)
    else:
        verdict = "OK"

    return verdict


if __name__ ==  "__main__":
    parser = OptionParser()
    parser.add_option("-f", dest="file", help="file containing elasticsearch or rsyslog dump")
    parser.add_option("-n", dest="expected", type="int", default=100, help="expected number of messages");

    (options, args) = parser.parse_args()
    expected = options.expected
    in_file = options.file

    pod_counts = {}

#   "message" : "2018-05-21 18:58:44,927 - SVTLogger - INFO - centos-logtest-bfkrm : 114 : HMhHxeSqV 6FHJrLGc7 7vSoNd4Kr ....
    message_id_regex = re.compile(".*SVTLogger - INFO - (centos-logtest-[a-z0-9]{5}) : (\d+)")

    with open(in_file,'r') as f:
        for line in f:
            result = message_id_regex.search(line)
            if result != None:
                pod_name = result.group(1)
                id = result.group(2)

                if not pod_name in pod_counts:
                    pod_counts[pod_name] = {}

                if not id in pod_counts[pod_name] :
                    pod_counts[pod_name][id] = 1
                else :
                    pod_counts[pod_name][id] += 1
        f.close()

    for pod in pod_counts:
        print "Verify pod: " + pod
        print "Verdict: " + verify(expected,pod_counts[pod]) + "\n"


