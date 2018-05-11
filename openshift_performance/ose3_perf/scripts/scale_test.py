from optparse import OptionParser
import time
import subprocess
import sys

global globalconfig

def login(url, user, passwd):
    run("oc login --insecure-skip-tls-verify=true -u " + user + " -p " + passwd + " " + url)

def run(cmd):
    result = subprocess.check_output(cmd,stderr=subprocess.STDOUT,shell=True)
    return result

def count_pods(namespace,dc) :
    pod_list = run("oc get pods --no-headers --show-labels -n " + namespace + " -l deploymentconfig=" + dc).rstrip().split('\n')
    running = 0
    active = 0
    for pod in pod_list:
        if not pod == "" and not pod=="No resources found.":
            active +=1
            if pod.find("Running") > -1 and pod.find("1/1") > -1:
                running += 1

    return running,active



def scale_down(namespace,dc):
    running,active = count_pods(namespace, dc)
    print "Scale down: Found " + str(active) + " pods active"
    if active > 0 :
        run("oc scale --replicas=0 -n " + namespace + " dc/" + dc)
        retries = 0
        while active > 0 and retries < 100:
            time.sleep(3)
            running,active = count_pods(namespace, dc)
            if active > 0:
                print "Scale down: " + str(active) + " pods still active"
            retries += 1

        if active > 0 :
            return False

    return True

def scale_up(namespace,dc,replicas) :
    print "Scaling up to " + str(replicas)
    run("oc scale -n " + namespace + " --replicas=" + str(replicas) + " dc/" + dc)
    start = time.time();
    current = count_pods(namespace, dc)[0]
    while current < replicas:
        time.sleep(3)
        current = count_pods(namespace,dc)[0]
        print "Running: " + str(current)
    stop=time.time()
    return int(stop - start)




if __name__ ==  "__main__":

    parser = OptionParser()
    parser.add_option("-m", "--master", dest="master",
                     help="url of the OpenShift master to login to")
    parser.add_option("-u", "--user", dest="oseuser",
                     help="OpenShift user for login")
    parser.add_option("-p", "--password", dest="osepass",
                     help="OpenShift password for login")
    parser.add_option("-d", "--dc", dest="dc",
                      help="Deployment Config")
    parser.add_option("-n", "--namespace", dest="namespace",
                      help="Namespace")
    parser.add_option("-r", "--replicas", dest="replicas", default=1,
                      help="Number of replicas")
    parser.add_option("-s", "--step-size", dest="step_size", default=0,
                      help="Step size")
    parser.add_option("-w", "--wait", dest="wait", default=0,
                      help="Wait time between steps")
    parser.add_option("-i", "--incremental", dest="incremental", action="store_true",
                      help="Do not scale down at the beginning")
    parser.add_option("-z", "--zero", dest="zero", action="store_true",
                      help="Return to zero replicas between steps")
    parser.add_option("-0", "--zero-final", dest="zero_final", action="store_true",
                      help="Return to zero replicas at the end of execution")


    globalconfig = {}

    (options, args) = parser.parse_args()
    globalconfig["master"] = options.master
    globalconfig["oseuser"] = options.oseuser
    globalconfig["password"] = options.osepass
    globalconfig["dc"] = options.dc
    globalconfig["replicas"] = int(options.replicas)
    globalconfig["namespace"] = options.namespace
    globalconfig["step_size"] = int(options.step_size)
    globalconfig["wait"] = int(options.wait)
    globalconfig["incremental"] = options.incremental
    globalconfig["zero"] = options.zero
    globalconfig["zero_final"] = options.zero_final

    login(globalconfig["master"],globalconfig["oseuser"],globalconfig["password"])

    total_replicas = globalconfig["replicas"]
    cumulative_replicas = 0
    previous_replicas = 0
    is_first_scaleup = True
    total_scaleup_time = 0
    run_start_time = time.time()

    while cumulative_replicas < total_replicas:
        if globalconfig["step_size"] == 0:
            # one shot scale up
            current_scaleup = total_replicas
        else:
            current_scaleup = cumulative_replicas + globalconfig["step_size"]
            if globalconfig["wait"] > 0 and not is_first_scaleup:
                time.sleep(globalconfig["wait"])


        if globalconfig["zero"] or (is_first_scaleup and not globalconfig["incremental"]):
            if not scale_down(globalconfig["namespace"], globalconfig["dc"]):
                print "Could not scale number of replicas to 0"
                sys.exit(-1)
            else:
                previous_replicas = 0
                is_first_scaleup=False
        elif is_first_scaleup and globalconfig["incremental"]:
            running,active = count_pods(globalconfig["namespace"], globalconfig["dc"])
            if current_scaleup > running:
                current_scaleup = current_scaleup - running
            else:
                current_scaleup = running
            is_first_scaleup=False

        elapsed = scale_up(globalconfig["namespace"], globalconfig["dc"], current_scaleup)
        total_scaleup_time += elapsed
        if not globalconfig["zero"]:
            previous_replicas = cumulative_replicas
        cumulative_replicas = current_scaleup
        print str(elapsed) + " seconds to scale dc " + globalconfig["dc"] + " from " + str(previous_replicas) + " to " + str(cumulative_replicas) + " replicas"

    run_stop_time=time.time()
    if globalconfig["zero_final"]:
        scale_down(globalconfig["namespace"], globalconfig["dc"])
        
    print "Total seconds for all scaleup operations (excluding sleep time): " + str(total_scaleup_time)
    print "Elapsed seconds for the test (scaleup + sleep): " + str(run_stop_time - run_start_time)

