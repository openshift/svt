from optparse import OptionParser
import time
import subprocess
import sys
import re

global globalconfig

def login(url, user, passwd):
    run("oc login --insecure-skip-tls-verify=true -u " + user + " -p " + passwd + " " + url)

def run(cmd):
    result = subprocess.check_output(cmd,stderr=subprocess.STDOUT,shell=True)
    return result



login("localhost:8443", "redhat", "redhat")


sleep_time = 15
max_retries = 40
retries=0
apps_found = 0;
apps_not_running = sys.argv[1:]
apps_needed = len(apps_not_running)

while apps_found < apps_needed and retries < max_retries:
    result = run("oc get dc --all-namespaces")
    print result
    apps_to_look_for = apps_not_running[0:]
    for app in apps_to_look_for:
        namespace,dc = app.split(":")
        print namespace + " " + dc
        # dancer-mysql0        dancer-mysql-example       1          1         1         config,image(dancer-mysql-example:latest)
        dc_running_regex = ".*" + namespace + "\s+" + dc + "\s+\d+\s+1\s+1"
        if re.search(dc_running_regex, result):
            print "Found: " + app
            apps_found += 1
            apps_not_running.remove(app)

    print "The following apps still not running: " + str(apps_not_running)
    if apps_found < apps_needed:
        time.sleep(sleep_time)
        retries += 1

exit_code = apps_needed - apps_found
print "exiting with code: " + str(exit_code)
sys.exit(exit_code)


