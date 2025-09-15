#!/usr/bin/env python
import re
import subprocess
import json
import time
from datetime import datetime
import random
import sys
import math
from optparse import OptionParser
# pip install futures
from concurrent.futures import ThreadPoolExecutor, wait
# https://github.com/wroberts/pytimeparse
# pip install pytimeparse
from pytimeparse.timeparse import timeparse
import logging


def run(cmd, config=""):

    if config:
        cmd = "KUBECONFIG=" + config + " " + cmd
    result = subprocess.check_output(cmd, stderr=subprocess.STDOUT, shell=True)
    return result


def login(url, user, passwd):
    run("oc login --insecure-skip-tls-verify=true -u " + user + " -p " + passwd
        + " " + url)
    # run("oc login https://api.dev-preview-int.openshift.com "
    #    "--token=yPeDkR0b0ESwbX2WlC4AGWqQIHJHIeRbrEOOua9HEoQ")


def analyze_builds(all_builds):
    wait_flag = False
    for build in all_builds:
        namespace = build["namespace"]
        name = build["name"]
        global_build_status[namespace + ":" + name] = STATUS_STARTED

    
    with ThreadPoolExecutor(max_workers=global_config["worker"]) \
            as executor:
        futures = []
        check_build_status(executor, futures, wait_flag)
        wait_flag = False
        logger.debug("str(len(futures)): " + str(len(futures)))
        wait(futures)

    time.sleep(int(global_config["sleep_time"]))
    


def check_build_status(executor, futures, wait_flag):
    logger.info("check_build_status ...")
    # wait the first build is started
    if wait_flag:
        logger.info("wait 2 in check_build_status")
        time.sleep(2)
    else:
        logger.info("no wait in check_build_status")
    while not all_builds_completed():
        try:
            time.sleep(2)
            result = run("oc get build --all-namespaces --no-headers -o json --sort-by='{.metadata.creationTimestamp}'")
            result_json = json.loads(result)
            parse(executor, result_json, futures)
        except Exception as e:
            logger.error(e)


def all_builds_completed():
    for value in global_build_status.values():
        if value < 200:
            return False
    return True


def parse(executor, result, futures):

    for build_stats_key in  global_build_status.keys(): 
        for build in result['items']:
            status = build['status']['phase']
            namespace = build['metadata']['namespace']
            name = build['metadata']['name']
            idx = namespace + ":" + name
            if idx == build_stats_key:
                if (global_build_status[idx] >= STATUS_COMPLETE):
                    break
                creation_timestamp = datetime.strptime(build['metadata']['creationTimestamp'],'%Y-%m-%dT%H:%M:%SZ')
                lastUpdateTime = datetime.now()
                if (status.startswith("Failed")) or (status == "Cancelled") or \
                        (status.startswith("Error")):
                        global_build_status[idx] = STATUS_ERROR
                        global_build_stats["failed"] += 1
                elif "Complete" == status:

                    for conditions in build['status']['conditions']:
                        if conditions['type'] == "Complete":
                            lastUpdateTime = datetime.strptime(conditions['lastUpdateTime'],'%Y-%m-%dT%H:%M:%SZ')
                            break
                    global_build_status[idx] = STATUS_COMPLETE
                    duration = lastUpdateTime - creation_timestamp
                    futures.append(
                        executor.submit(do_post_actions, namespace,
                                        name, duration.total_seconds()))
                break

def do_post_actions(namespace, build_name, build_time):
    idx = namespace + ":" + build_name
    try:

        if (global_build_status[idx] > STATUS_COMPLETE) and (global_build_status[idx] < STATUS_COMPLETE):
            return
        global_build_status[idx] = STATUS_LOGGING
        start_regex = ".*[\d]*-[\d]*-[\d]*T[\d]*:[\d]*:[\d]*.[\d]*Z\sPushing"
        end_regex =".*[\d]*-[\d]*-[\d]*T[\d]*:[\d]*:[\d]*.[\d]*Z\sSuccessfully pushed|Push successful"
        push_date_fmt = "%Y-%m-%dT%H:%M:%S.%f"

        command = "oc logs --timestamps -n " + namespace + " build/" + \
                  build_name
        logger.debug(command)
        result = str(run(command))

        # calculate and record stats
        try:
            # timestamps for start and end of push.
            # End of push message different for non-s2i builds
            push_start = re.search(start_regex, result)
            push_start0 = push_start.group(0)
            push_start1 = push_start0.split('\\n')[-1].split(' ')[0][:-4]
            
            push_end = re.search(end_regex, result)
            push_end0 = push_end.group(0)

            push_end0 = push_end0.split('\\n')[-1].split(" ")[0][:-4]

            # print("push_start: " + str(push_start))
            # print("push_end: " + str(push_end))
            push_time_delta = datetime.strptime(
                push_end0, push_date_fmt) - datetime.strptime(
                push_start1, push_date_fmt)
            push_time = push_time_delta.total_seconds()
        except Exception:
            push_time = 0
            logger.exception("cannot get push time strings from " + str(result))

        if (build_time == 0) or (push_time == 0):
            logger.info("Invalid data - not included in summary statistics: " + namespace + ":" + build_name)
            global_build_stats["invalid"] += 1
            global_build_status[idx] = STATUS_LOGGING_ERROR
        else:
            global_build_status[idx] = STATUS_LOGGED
            global_build_stats["num"] += 1
            global_build_stats["build_time"] += build_time
            global_build_stats["push_time"] += push_time
            if build_time > global_build_stats["max_build"]:
                global_build_stats["max_build"] = build_time
            if build_time < global_build_stats["min_build"]:
                global_build_stats["min_build"] = build_time
            if push_time > global_build_stats["max_push"]:
                global_build_stats["max_push"] = push_time
            if push_time < global_build_stats["min_push"]:
                global_build_stats["min_push"] = push_time
    
    except Exception as e:
        global_build_status[idx] = STATUS_LOGGING_ERROR
        logger.error("error in post " + str(e))


# Select a random set of builds to run.  Duplicates not allowed
def select_random_builds(builds, num):
    if len(builds) < num:
        raise ValueError('It is not possible to select %d builds from build'
                         ' source containing only %d builds'
                         % (num, len(builds)))
    selected_builds = []
    seen = set()
    i = 0
    while i < num:
        chosen_build = random.choice(builds)
        build_idx = chosen_build["namespace"] + ":" + chosen_build["name"]
        if build_idx not in seen:
            seen.add(build_idx)
            selected_builds.append(chosen_build)
            i += 1
    return selected_builds


def set_global_stats_dict():
    # init statistics
    global global_build_stats
    global_build_stats = {"num": 0, "build_time": 0, "max_build": 0,
                                "min_build": math.inf, "push_time": 0,
                                "max_push": 0, "min_push": math.inf,
                                "build_time_variance": 0,
                                "push_time_variance": 0,
                                "failed": 0, "invalid": 0}

def run_build(build_def):
    namespace = build_def["namespace"]
    name = build_def["name"]
    build_name = "UNKNOWN"

    try:
        build_name = str(run("oc start-build -n " + namespace + " " + name)).rstrip().split('/')[-1].split( )[0]
        if "UNKNOWN" == build_name:
            global_build_status[namespace + ":" + build_name] = STATUS_ERROR
        else: 
            global_build_status[namespace + ":" + build_name] = STATUS_STARTED
       
    except subprocess.CalledProcessError as err:
        if "UNKNOWN" != build_name:
            global_build_status[namespace + ":" + build_name] = STATUS_ERROR
        logger.error("Command failed:  tproject=" + namespace + ",cmd=" +
                     err.cmd + ", retcode=" + str(err.returncode) + ", output="
                     + err.output)
    except Exception as e:
        logger.error(e)
    

# Run builds simultaneously in background threads
def run_builds(executor, executor1, all_builds):
    global global_config
    if global_config["random"] > 0:
        selected_builds = select_random_builds(all_builds,
                                               global_config["random"])
    else:
        selected_builds = all_builds[0:]

    if global_config["shuffle"]:
        selected_builds = random.sample(selected_builds,
                                        len(selected_builds))

    if global_config["batch"] == 0:
        batch_size = len(selected_builds)
    else:
        batch_size = global_config["batch"]

    final_selected_builds = selected_builds
    #logger.info('selected builds ' + str(selected_builds))
    wait_flag = True
    while len(selected_builds) > 0:
        this_batch_count = 0
        futures = []
        while this_batch_count < batch_size and len(selected_builds) > 0:
            build = selected_builds.pop()
            this_batch_count += 1
            futures.append(executor.submit(run_build, build))

        logger.info("All threads started, starting builds")
        logger.debug("str(len(futures)): " + str(len(futures)))
        wait(futures)
        
        futures1 = []
        check_build_status(executor1, futures1, wait_flag)
        wait_flag = False
        logger.debug("str(len(futures1)): " + str(len(futures1)))
        wait(futures1)

        time.sleep(int(global_config["sleep_time"]))



def get_build_configs():
    all_builds = []
    try:
        output = run("oc get --all-namespaces=true -o json bc")
        build_configs = json.loads(output)
        if build_configs:
            for build in build_configs["items"]:
                all_builds.append({"namespace": build["metadata"]["namespace"],
                                "name": build["metadata"]["name"]})
        return all_builds
    except Exception:
        logger.exception("cannot get BCs from the output: " + output)
        sys.exit(1)

def start():
    global global_config
    global global_build_stats
    global global_build_status
    parser = OptionParser()
    parser.add_option("-m", "--master", dest="master",
                      help="url of the OpenShift master to login to")
    parser.add_option("-u", "--user", dest="oseuser",
                      help="OpenShift user for login")
    parser.add_option("-p", "--password", dest="osepass",
                      help="OpenShift password for login")
    parser.add_option("-a", "--all", dest="allbuilds", action="store_true",
                      help="Run all builds in all projects")
    parser.add_option("-l", "--shuffle", dest="shuffle", action="store_true",
                      help="Shuffle the order of the selected builds")
    parser.add_option("-f", "--file", dest="buildfile",
                      help="JSON file with builds to run")
    parser.add_option("-n", "--numiter", dest="num", default=1,
                      help="Number of iterations")
    parser.add_option("-b", "--batch", dest="batch", default=0,
                      help="Number of iterations")
    parser.add_option("-s", "--sleep", dest="sleep", default=0,
                      help="Seconds to sleep between iterations")
    parser.add_option("-r", "--random", dest="random", default=0,
                      help="Number of builds to select randomly "
                           "on each iteration")
    parser.add_option("-z", dest="nologin", action="store_true", default=False,
                      help="Bypass oc login")
    parser.add_option("-d", "--debug", dest="debug", action="store_true",
                      help="Debug messages")
    parser.add_option("-w", "--worker", dest="worker", default=50,
                      help="Number of workers")
    parser.add_option("-y", "--analyze", dest="analyze", action="store_true", default=False,
                      help="Analyze the results of existing builds")

    random.seed()

    (options, args) = parser.parse_args()
    global_config["master"] = options.master
    global_config["oseuser"] = options.oseuser
    global_config["password"] = options.osepass
    global_config["all_builds"] = options.allbuilds
    global_config["build_file"] = options.buildfile
    global_config["num_iterations"] = int(options.num)
    global_config["sleep_time"] = int(options.sleep)
    global_config["debug"] = options.debug
    global_config["random"] = int(options.random)
    global_config["batch"] = int(options.batch)
    global_config["shuffle"] = options.shuffle
    global_config["nologin"] = options.nologin
    global_config["worker"] = int(options.worker)
    global_config["analyze"] = options.analyze

    if not global_config["nologin"]:
        login(global_config["master"], global_config["oseuser"],
              global_config["password"])

    logger.info("Gathering build info...")
    if global_config["build_file"]:
        with open(global_config["build_file"]) as f:
            builds = f.read().replace('\n', '')
            all_builds = json.loads(builds)
    else:
        all_builds = get_build_configs()

    logger.info("Build info gathered.")
    set_global_stats_dict()
    #https://stackoverflow.com/questions/2427240/thread-safe-equivalent-to-pythons-time-strptime
    datetime.strptime('', '')
    if not global_config["analyze"]:
        for i in range(0, global_config["num_iterations"]):
            global global_build_status
            global_build_status = {}
            logger.info(str(datetime.now()).split('.')[0] +
                        ": iteration: " + str(i + 1))

            with ThreadPoolExecutor(max_workers=global_config["worker"]) \
                    as executor:
                with ThreadPoolExecutor(max_workers=global_config["worker"]) \
                        as executor1:
                    run_builds(executor, executor1, all_builds)
    else:
        global_build_status = {}
        analyze_builds(all_builds)
        
    total_all_builds = global_build_stats["build_time"]
    max_all_builds = global_build_stats["max_build"]
    min_all_builds = global_build_stats["min_build"]

    total_all_pushes = global_build_stats["push_time"]
    max_all_pushes = global_build_stats["max_push"]
    min_all_pushes = global_build_stats["min_push"]

    total_builds = global_build_stats["num"]

    total_failed = global_build_stats["failed"]
    total_invalid = global_build_stats["invalid"]

    if total_builds > 0:
        logger.info("Failed builds: " + str(total_failed))
        logger.info("Invalid builds: " + str(total_invalid))
        logger.info("Good builds included in stats: " + str(total_builds))
        logger.info("Average build time, all good builds: " +
                    str(total_all_builds/total_builds))
        logger.info("Minimum build time, all good builds: " +
                    str(min_all_builds))
        logger.info("Maximum build time, all good builds: " +
                    str(max_all_builds))
        logger.info("Average push time, all good builds: " +
                    str(total_all_pushes/total_builds))
        logger.info("Minimum push time, all good builds: " +
                    str(min_all_pushes))
        logger.info("Maximum push time, all good builds: " +
                    str(max_all_pushes))


def init_logger(my_logger):
    my_logger.setLevel(logging.DEBUG)
    fh = logging.FileHandler('/tmp/build_test.log')
    fh.setLevel(logging.DEBUG)
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(threadName)s '
                                  '- %(levelname)s - %(message)s')
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)
    my_logger.addHandler(fh)
    my_logger.addHandler(ch)

global_config = {}
global_build_stats = {}
global_build_status = {}

STATUS_STARTED = 1
STATUS_COMPLETE = 200
STATUS_LOGGING = 210
STATUS_NOT_COMPLETE = 300
STATUS_LOGGED = 301
STATUS_ERROR = 400
STATUS_LOGGING_ERROR = 401

if __name__ == "__main__":
    logger = logging.getLogger('build_test')
    init_logger(logger)
    start()
