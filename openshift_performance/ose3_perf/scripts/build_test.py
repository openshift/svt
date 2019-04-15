#!/usr/bin/env python
import re
import subprocess
import json
import time
from datetime import datetime
import random
import sys
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


def run_build(build_def):
    build_regex = re.compile("build.build.openshift.io\/(.*) started")

    namespace = build_def["namespace"]
    name = build_def["name"]
    build_name = "UNKNOWN"

    try:

        build_name = run("oc start-build -n " + namespace + " " + name).rstrip()
        # 3.2 Comment out following line
        build_name = build_regex.search(build_name).group(1)
        global_build_status[namespace + ":" + build_name] = STATUS_STARTED
        logger.info("Build is: " + namespace + ":" + build_name)

    except subprocess.CalledProcessError as err:
        if "UNKNOWN" != build_name:
            global_build_status[namespace + ":" + build_name] = STATUS_ERROR
        logger.error("Command failed:  tproject=" + namespace + ",cmd=" +
                     err.cmd + ", retcode=" + str(err.returncode) + ", output="
                     + err.output)
    except Exception as e:
        logger.error("cannot get build_name from: " + build_name)
        logger.error(e)


def check_build_status(executor, futures, wait_flag):
    logger.info("check_build_status ...")
    # wait the first build is started
    if wait_flag:
        logger.debug("wait 20 in check_build_status")
        time.sleep(20)
    else:
        logger.debug("no wait in check_build_status")
    while not all_builds_completed():
        try:
            time.sleep(10)
            result = run("oc get build --all-namespaces --no-headers")
            parse(executor, result, futures)
        except Exception as e:
            logger.error(e)


def all_builds_completed():
    logger.debug("global_build_status: " + str(global_build_status))
    for key, value in global_build_status.iteritems():
        if value < 300:
            return False
    return True


def parse(executor, result, futures):
    for line in result.splitlines():
        words = line.split()

        if len(words) >= 5:
            status = words[4]
            namespace = words[0]
            name = words[1]
            duration_string = words[-1]
            idx = namespace + ":" + name
            if (status.startswith("Failed")) or (status == "Cancelled") or \
                    (status.startswith("Error")):
                if idx in global_build_status.keys():
                    logger.debug(idx + " FAILED")
                    if global_build_status[idx] < STATUS_NOT_COMPLETE:
                        global_build_status[idx] = STATUS_NOT_COMPLETE
                        stats_idx = idx[0:idx.rindex('-')]
                        global_build_stats[stats_idx]["failed"] += 1
            elif "Complete" == words[4]:
                if idx in global_build_status.keys():
                    if global_build_status[idx] < STATUS_COMPLETE:
                        logger.info(idx + " Complete, Duration = " + duration_string)
                        global_build_status[idx] = STATUS_COMPLETE
                    if global_build_status[idx] < STATUS_LOGGING:
                        futures.append(
                            executor.submit(do_post_actions, namespace,
                                            name, timeparse(duration_string)))
        else:
            logger.error("unexpected return "
                         "(oc get build --all-namespaces --no-headers): "
                         + result)


def do_post_actions(namespace, build_name, build_time):
    idx = namespace + ":" + build_name
    try:
        if (global_build_status[idx] >= STATUS_LOGGING) or \
                (global_build_status[idx] < STATUS_COMPLETE):
            return
        global_build_status[idx] = STATUS_LOGGING
        start_regex = re.compile(
            ".*(\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d).\d+Z\sPushing")
        end_regex = re.compile(
            ".*(\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d).\d+Z\s(Successfully pushed|"
            + "Push successful)")
        push_date_fmt = "%Y-%m-%dT%H:%M:%S"

        command = "oc logs --timestamps -n " + namespace + " build/" + \
                  build_name
        logger.debug(command)
        result = run(command)

        # calculate and record stats
        try:
            # timestamps for start and end of push.
            # End of push message different for non-s2i builds
            push_start = start_regex.search(result).group(1)
            push_end = end_regex.search(result).group(1)
            logger.debug("push_start: " + push_start)
            logger.debug("push_end: " + push_end)
            push_time_delta = datetime.strptime(
                push_end, push_date_fmt) - datetime.strptime(
                push_start, push_date_fmt)
            push_time = push_time_delta.total_seconds()
        except Exception:
            push_time = 0
            logger.exception("cannot get push time strings from " + result)

        stats_idx = idx[0:idx.rindex('-')]
        if (build_time == 0) or (push_time == 0):
            logger.info("Invalid data - not included in summary statistics")
            global_build_stats[stats_idx]["invalid"] += 1
            global_build_status[idx] = STATUS_LOGGING_ERROR
        else:
            global_build_status[idx] = STATUS_LOGGED
            global_build_stats[stats_idx]["num"] += 1
            global_build_stats[stats_idx]["build_time"] += build_time
            global_build_stats[stats_idx]["push_time"] += push_time
            if build_time > global_build_stats[stats_idx]["max_build"]:
                global_build_stats[stats_idx]["max_build"] = build_time
            if build_time < global_build_stats[stats_idx]["min_build"]:
                global_build_stats[stats_idx]["min_build"] = build_time
            if push_time > global_build_stats[stats_idx]["max_push"]:
                global_build_stats[stats_idx]["max_push"] = push_time
            if push_time < global_build_stats[stats_idx]["min_push"]:
                global_build_stats[stats_idx]["min_push"] = push_time
    except Exception as e:
        global_build_status[idx] = STATUS_LOGGING_ERROR
        logger.error(e)


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

    wait_flag = True
    while len(selected_builds) > 0:
        this_batch_count = 0
        futures = []
        while this_batch_count < batch_size and len(selected_builds) > 0:
            build = selected_builds.pop()
            this_batch_count += 1
            futures.append(executor.submit(run_build, build))

        logger.info("All threads started, starting builds")
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

    # init statistics
    for build in all_builds:
        idx = build["namespace"] + ":" + build["name"]
        global_build_stats[idx] = {"num": 0, "build_time": 0, "max_build": 0,
                                   "min_build": sys.maxint, "push_time": 0,
                                   "max_push": 0, "min_push": sys.maxint,
                                   "build_time_variance": 0,
                                   "push_time_variance": 0,
                                   "failed": 0, "invalid": 0}

    #https://stackoverflow.com/questions/2427240/thread-safe-equivalent-to-pythons-time-strptime
    datetime.strptime('', '')
    for i in range(0, global_config["num_iterations"]):

        logger.info(str(datetime.now()).split('.')[0] +
                    ": iteration: " + str(i + 1))

        with ThreadPoolExecutor(max_workers=global_config["worker"]) \
                as executor:
            with ThreadPoolExecutor(max_workers=global_config["worker"]) \
                    as executor1:
                run_builds(executor, executor1, all_builds)


    # output stats
    total_all_builds = 0
    total_all_pushes = 0
    total_failed = 0
    total_invalid = 0
    total_builds = 0
    max_all_builds = -1
    min_all_builds = sys.maxint
    max_all_pushes = -1
    min_all_pushes = sys.maxint

    for build in all_builds:
        idx = build["namespace"] + ":" + build["name"]
        num = global_build_stats[idx]["num"]

        if num > 0:
            logger.info("Build: " + idx)
            logger.info("\tTotal builds: " +
                        str(global_build_stats[idx]["num"]) +
                        " Failures: " + str(global_build_stats[idx]["failed"]))
            logger.info("\tAvg build time: " +
                        str(global_build_stats[idx]["build_time"]/num) +
                        " Max build time: " +
                        str(global_build_stats[idx]["max_build"]) +
                        " Min build time: " +
                        str(global_build_stats[idx]["min_build"]))
            logger.info("\tAvg push time: " +
                        str(global_build_stats[idx]["push_time"]/num) +
                        " Max push time: " +
                        str(global_build_stats[idx]["max_push"]) +
                        " Min push time: " +
                        str(global_build_stats[idx]["min_push"]))
            total_all_builds += global_build_stats[idx]["build_time"]
            if global_build_stats[idx]["max_build"] > max_all_builds:
                max_all_builds = global_build_stats[idx]["max_build"]
            if global_build_stats[idx]["min_build"] < min_all_builds:
                min_all_builds = global_build_stats[idx]["min_build"]

            total_all_pushes += global_build_stats[idx]["push_time"]
            if global_build_stats[idx]["max_push"] > max_all_pushes:
                max_all_pushes = global_build_stats[idx]["max_push"]
            if global_build_stats[idx]["min_push"] < min_all_pushes:
                min_all_pushes = global_build_stats[idx]["min_push"]

            total_builds += global_build_stats[idx]["num"]
        else:
            logger.debug(idx + ": No successful builds")

        total_failed += global_build_stats[idx]["failed"]
        total_invalid += global_build_stats[idx]["invalid"]

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
