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

# Starting in OCP 4.1, added arguments for login() method:
if __name__ ==  "__main__":

    parser = OptionParser()
    parser.add_option("-a", "--apiurl", dest="apiurl",
                     help="url of the OpenShift master to login to")
    parser.add_option("-u", "--user", dest="oseuser",
                     help="OpenShift user for login")
    parser.add_option("-p", "--password", dest="osepass",
                     help="OpenShift password for login")
    parser.add_option("-n", "--namespace-dc-pairs", dest="namespace_dc_pairs",
                     help="Comma separated string containing namespace:dc pairs")

    globalconfig = {}

    (options, args) = parser.parse_args()
    globalconfig["apiurl"] = options.apiurl
    globalconfig["oseuser"] = options.oseuser
    globalconfig["password"] = options.osepass
    globalconfig["namespace_dc_pairs"] = options.namespace_dc_pairs

    login(globalconfig["apiurl"],globalconfig["oseuser"],globalconfig["password"])

    sleep_time = 15
    max_retries = 40
    retries=0
    apps_found = 0;
    namespace_dc_pairs = globalconfig["namespace_dc_pairs"].split()
    apps_not_running = namespace_dc_pairs
    print apps_not_running
    
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


