#!/usr/bin/env python

import json, subprocess, time, copy, sys, os, yaml, tempfile, shutil, math, re
from datetime import datetime
from clusterloaderstorage import *
from multiprocessing import Process
from flask import Flask, request
import logging

formatter = logging.Formatter(fmt='%(asctime)s :: %(process)d :: %(levelname)-8s :: %(message)s', datefmt='%Y-%m-%d::%H:%M:%S')
screen_handler = logging.StreamHandler(stream=sys.stdout)
screen_handler.setFormatter(formatter)
logger = logging.getLogger("clusterloader")
logger.setLevel(logging.INFO)
logger.addHandler(screen_handler)

def calc_time(timestr):
    tlist = timestr.split()
    if tlist[1] == "s":
        return int(tlist[0])
    elif tlist[1] == "min":
        return int(tlist[0]) * 60
    elif tlist[1] == "ms":
        return int(tlist[0]) / 1000
    elif tlist[1] == "hr":
        return int(tlist[0]) * 3600
    else:
        logger.error("Invalid delay in rate_limit Exitting ........")
        sys.exit()

def oc_command(args, globalvars):
    """Run the OC/kubectl Command and return tuple with stdout, stderr, and return code"""
    tmpfile=tempfile.NamedTemporaryFile()
    # see https://github.com/openshift/origin/issues/7063 for details why this is done.
    shutil.copyfile(globalvars["kubeconfig"], tmpfile.name)
    cmd = "KUBECONFIG=" + tmpfile.name + " " + args
    process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()
    if process.returncode != 0:
        logger.error("OC_Command: {} :: Return Code: {}".format(cmd, process.returncode))
    else:
        logger.info("OC_Command: {} :: Return Code: {}".format(cmd, process.returncode))
    logger.debug("stdout: %s", str(stdout).strip())
    logger.debug("stderr: %s", str(stderr).strip())
    tmpfile.close()
    return stdout, stderr, process.returncode

def oc_command_with_retry(args, globalvars, max_retries=10, backoff_period=10):
    """Run the oc_command function but check returncode for 0, retry otherwise"""
    output = oc_command(args, globalvars)
    retry_count = 0
    while (output[2] != 0):
        if retry_count >= max_retries:
            logger.error("Unable to complete with {} retries".format(retry_count))
            break
        retry_count += 1
        retry_time = retry_count * backoff_period
        logger.warn("{} Retry of OC command in {}s".format(retry_count, retry_time))
        time.sleep(retry_time)
        output = oc_command(args, globalvars)
    return output

def login(user,passwd,master):
    return subprocess.check_output("oc login --insecure-skip-tls-verify=true -u " + user + " -p " + passwd + " " + master,shell=True)

def check_oc_version(globalvars):
    major_version = 0;
    minor_version = 0;

    if globalvars["kubeopt"]:
        version_string = oc_command("kubectl version", globalvars)
        result = re.search("Client Version: version.Info\{Major:\"(\d+)\", Minor:\"(\d+)\".*", version_string[0])
        if result:
            major_version = result.group(1)
            minor_version = result.group(2)
    else:
        version_string = oc_command("oc version", globalvars)
        result = re.search("oc v(\d+)\.(\d+)\..*", version_string[0])
        if result:
            major_version = result.group(1)
            minor_version = result.group(2)
    return {"major":major_version, "minor": minor_version}


def get_route():
    default_proj = subprocess.check_output("oc project default", shell=True)
    localhost = subprocess.check_output("ip addr show eth0 | awk '/inet / {print $2;}' | cut -d/ -f1", shell=True).rstrip()
    router_name = subprocess.check_output("oc get pod --no-headers | head -n -1 | awk '/^router-/ {print $1;}'", shell=True).rstrip()
    router_ip = subprocess.check_output("oc get pod --template=\"{{{{ .status.podIP }}}}\" {0}".format(router_name), shell=True).rstrip()
    spawned_project_list = subprocess.check_output("oc get projects -l purpose=test --no-headers | awk '{print $1;}'", shell=True)

    routes_list = []
    for project in spawned_project_list.splitlines():
        project_routes = subprocess.check_output("oc get routes --no-headers -n {0} | awk '{{ print $2 }}'".format(project), shell=True)
        routes_list.extend([y for y in (x.strip() for x in project_routes.splitlines()) if y])

    return localhost, router_ip, routes_list

def create_template(templatefile, num, parameters, globalvars):
    logger.debug("create_template function called")

    parameter_flag = "-p"

    if globalvars["autogen"] and parameters:
        localhost, router_ip, jmeter_ips = get_route()
        extra_param = {}
        extra_param['SERVER_RESULTS_DIR'] = os.environ.get('benchmark_run_dir','/tmp/')

        gun_env = os.environ.get('GUN')

        if gun_env:
            extra_param['GUN'] = gun_env
        else:
            gun_param = any(param for param in parameters if param.get('GUN'))

            if not gun_param:
                extra_param['GUN'] = localhost

        gun_port_env = os.environ.get('GUN_PORT')

        if gun_port_env:
            extra_param['GUN_PORT'] = gun_port_env
        else:
            gun_port_set = any(param for param in parameters if param.get('GUN_PORT'))

            if not gun_port_set:
                extra_param['GUN_PORT'] = 9090

        parameters.append(extra_param.copy())

        jmeter = any(param for param in parameters if param.get('RUN') == 'jmeter')
        if jmeter:
            for parameter in parameters:
                for key, value in parameter.iteritems():
                    if key == "JMETER_SIZE":
                        size = int(value)
            num = math.ceil(float(len(jmeter_ips))/size)
        globalvars["podnum"] += num
        create_wlg_targets("wlg-targets", globalvars)

    data = {}
    timings = {}
    i = 0
    while i < int(num):
        tmpfile=tempfile.NamedTemporaryFile()
        templatejson = copy.deepcopy(data)
        cmdstring = "oc process -f %s" % templatefile

        if parameters:
            for parameter in parameters:
                for key, value in parameter.iteritems():
                    if globalvars["autogen"] and jmeter:
                        if key == "TARGET_HOST":
                            value = ":".join(jmeter_ips[(size*i):(size*(i+1))])
                        elif key == "ROUTER_IP":
                            value = router_ip

                    cmdstring += " " + parameter_flag + " %s='%s'" % (key, value)
        cmdstring += " " + parameter_flag + " IDENTIFIER=%i" % i

        processedstr = oc_command_with_retry(cmdstring, globalvars)
        templatejson = json.loads(processedstr[0])
        json.dump(templatejson, tmpfile)
        tmpfile.flush()
        if globalvars["kubeopt"]:
            check = oc_command("kubectl create -f "+tmpfile.name + \
                " --namespace %s" % globalvars["namespace"], globalvars)
        else:
            check = oc_command_with_retry("oc create -f "+ tmpfile.name + \
                " --namespace %s" % globalvars["namespace"], globalvars)
        if "tuningset" in globalvars:
            if "templates" in globalvars["tuningset"]:
                templatestuningset = globalvars["tuningset"]["templates"]
                if "stepping" in templatestuningset:
                    stepsize = templatestuningset["stepping"]["stepsize"]
                    pause = templatestuningset["stepping"]["pause"]
                    globalvars["totaltemplates"] = globalvars["totaltemplates"] + 1
                    templates_created = int(globalvars["totaltemplates"])
                if templates_created % stepsize == 0:
                    time.sleep(calc_time(pause))
                if "rate_limit" in templatestuningset:
                    delay = templatestuningset["rate_limit"]["delay"]
                    time.sleep(calc_time(delay))

        i = i + 1
        tmpfile.close()


def create_wlg_targets(cm_targets, globalvars):
    namespace = globalvars["namespace"]
    output = oc_command("oc delete configmap %s -n %s" % (cm_targets, namespace), globalvars)
    if output[2] > 0:
        logger.debug("Command failed but pass according to old code")
    # try:
    #     oc_command("oc delete configmap %s -n %s" % (cm_targets, namespace), globalvars)
    # except subprocess.CalledProcessError:
    #     pass
    ret = oc_command("oc get routes --all-namespaces --no-headers | awk '{print $3}' | oc create configmap %s --from-file=wlg-targets=/dev/stdin -n %s" %
          (cm_targets, namespace), globalvars)
    return ret[0]


def create_service(servconfig, num, globalvars):
    logger.debug("create_service function called")

    data = {}
    timings = {}
    data = servconfig
    i = 0
    while i < int(num):
        tmpfile=tempfile.NamedTemporaryFile()
        dataserv = copy.deepcopy(data)
        servicename = dataserv["metadata"]["name"] + str(i)
        dataserv["metadata"]["name"] = servicename
        json.dump(dataserv, tmpfile)
        tmpfile.flush()

        if globalvars["kubeopt"]:
            check = oc_command("kubectl create -f " + tmpfile.name, \
                globalvars)
        else:
            check = oc_command("oc create -f " + tmpfile.name, \
                globalvars)
        i = i + 1
        del (dataserv)
        tmpfile.close()


def create_pods(podcfg, num, storagetype, globalvars):
    logger.debug("create_pods function called")

    namespace = podcfg["metadata"]["namespace"]
    data = {}
    timings = {}
    data = podcfg
    i = 0
    pend_pods = globalvars["pend_pods"]
    while i < int(num):
        if storagetype in ("ebs", "EBS"):
            # it is necessary to create ebs/pv/pvc for every pod, and pod file has to updated dinamically
            ebs_create(globalvars)
            tmpfile=tempfile.NamedTemporaryFile()
            datapod = copy.deepcopy(data)
            podname = datapod["metadata"]["name"] + str(i)
            datapod["metadata"]["name"] = podname

            datapod["spec"]["containers"][0]["volumeMounts"] = [{"mountPath" : mountdir ,"name": ebsvolumeid }]
            datapod["spec"]["volumes"] = [{"name": ebsvolumeid, "persistentVolumeClaim": { "claimName": ebsvolumeid }}]
            # update pod
            globalvars["curprojenv"]["pods"].append(podname)
            json.dump(datapod, open("podfilexample.json", "w+"), sort_keys=True, indent=4, separators=(',', ': '))
            json.dump(datapod, tmpfile)
            tmpfile.flush()

        elif storagetype in ("ceph", "CEPH"):
            ceph_image_create(i,globalvars) # this will create pv/pvc/image - one at time
            tmpfile = tempfile.NamedTemporaryFile()
            datapod = copy.deepcopy(data)
            podname = datapod["metadata"]["name"] + str(i)
            datapod["metadata"]["name"] = podname

            datapod["spec"]["containers"][0]["volumeMounts"] = [{"mountPath" : mountdir , "name": "cephvol" + str(i) }]
            datapod["spec"]["volumes"] = [{"name": "cephvol" + str(i) , "persistentVolumeClaim": { "claimName": "cephclaim" + str(i) }}]
            # update pod
            globalvars["curprojenv"]["pods"].append(podname)
            json.dump(datapod, open("podfilexample.json", "w+"), sort_keys=True, indent=4, separators=(',', ': '))
            json.dump(datapod, tmpfile)
            tmpfile.flush()

            """
            # do here ceph pv test configuration
            elif storagetype in ("nfs", "NFS"):
            # do here nfs pv test configuration
            elif storagetype in ("gluster", "GLUSTER"):
            # do here gluster configuration
            """

        # here will be added ceph_create/gluster_create / nfs_create / iscsi_create storage backends
        else:
            tmpfile=tempfile.NamedTemporaryFile()
            datapod = copy.deepcopy(data)
            podname = datapod["metadata"]["name"] + str(i)
            datapod["metadata"]["name"] = podname
            globalvars["curprojenv"]["pods"].append(podname)
            json.dump(datapod, tmpfile)
            tmpfile.flush()
        if globalvars["kubeopt"]:
            found = False
            while not found:
                check = oc_command("kubectl get serviceaccounts --namespace " + namespace, globalvars)
                if "default" in check:
                    found = True
            check = oc_command("kubectl create --validate=false -f " \
                + tmpfile.name, globalvars)
        else:
            check = oc_command("oc create -f " + tmpfile.name, \
                globalvars)
        pend_pods.append(podname)

        if "tuningset" in globalvars:
            if "stepping" in globalvars["tuningset"]:
                stepsize = globalvars["tuningset"]["stepping"]["stepsize"]
                pause = globalvars["tuningset"]["stepping"]["pause"]
                globalvars["totalpods"] = globalvars["totalpods"] + 1
                total_pods_created = int(globalvars["totalpods"])
                if total_pods_created % stepsize == 0 and globalvars["tolerate"] is False:
                    pod_data(globalvars)
                    time.sleep(calc_time(pause))
            if "rate_limit" in globalvars["tuningset"]:
                delay = globalvars["tuningset"]["rate_limit"]["delay"]
                time.sleep(calc_time(delay))

        i = i + 1
        del (datapod)
        tmpfile.close()


def pod_data(globalvars):
    logger.debug("pod_data function called")

    pend_pods = globalvars["pend_pods"]
    namespace = globalvars["namespace"]
    while len(pend_pods) > 0:
        if globalvars["kubeopt"]:
            getpods = oc_command("kubectl get pods --namespace " + namespace, globalvars)
        else:
            getpods = oc_command("oc get pods -n " + namespace, globalvars)
        all_status = getpods[0].split("\n")

        size = len(all_status)
        all_status = all_status[1:size - 1]
        for status in all_status:
            fields = status.split()
            if fields[2] == "Running" and fields[0] in pend_pods:
                pend_pods.remove(fields[0])
        if len(pend_pods) > 0:
           time.sleep(5)


def create_rc(rc_config, num, globalvars):
    logger.debug("create_rc function called")

    i = 0
    data = rc_config
    basename = rc_config["metadata"]["name"]

    while i < num:
        tmpfile=tempfile.NamedTemporaryFile()
        curdata = copy.deepcopy(data)
        newname = basename + str(i)
        globalvars["curprojenv"]["rcs"].append(newname)
        curdata["metadata"]["name"] = newname
        curdata["spec"]["selector"]["name"] = newname
        curdata["spec"]["template"]["metadata"]["labels"]["name"] = newname
        json.dump(curdata, tmpfile)
        tmpfile.flush()
        if globalvars["kubeopt"]:
            oc_command("kubectl create -f " + tmpfile.name, globalvars)
        else:
            oc_command("oc create -f " + tmpfile.name, globalvars)
        i = i + 1
        del (curdata)
        tmpfile.close()


def create_user(usercfg, globalvars):
    logger.debug("create_user function called")

    namespace = globalvars["namespace"]
    basename = usercfg["basename"]
    num = int(usercfg["num"])
    role = usercfg["role"]
    password = usercfg["password"]
    passfile = usercfg["userpassfile"]
    i = 0
    while i < num:
        name = basename + str(i)
        globalvars["curprojenv"]["users"].append(name)
        # TO BE DISCUSSED
        # cmdstring = "id -u " + name + " &>/dev/null | useradd " + name
        # subprocess.check_call(cmdstring, shell=True)
        if not os.path.isfile(passfile):
            subprocess.check_call("touch " + passfile, shell = True)
        subprocess.check_call("htpasswd -b " + passfile + " " + name + " " + \
                        password, shell=True)
        oc_command("oc adm policy add-role-to-user " + role + " " + name + \
                        " -n " + namespace, globalvars)
        logger.info("Created User: " + name + " :: " + "Project: " + namespace + " :: " + "role: " + role)
        i = i + 1


def project_exists(projname, globalvars) :
    exists = False
    try :
        cmd = "kubectl" if globalvars["kubeopt"] else "oc"
        output = oc_command(cmd + " get project -o name " + projname, globalvars)[0].rstrip()
        if output.endswith(projname) :
            exists = True
    except subprocess.CalledProcessError : # this is ok, means the project does not already exist
        pass

    return exists

def delete_project(projname, globalvars) :
    # Check if the project exists
    cmd = "kubectl" if globalvars["kubeopt"] else "oc"
    oc_command(cmd + " delete project " + projname, globalvars)

    # project deletion is asynch from resource deletion.  command returns before project is really gone
    retries = 0
    while project_exists(projname,globalvars) and (retries < 10) :
        retries += 1
        logger.info("Project " + projname + " still exists, waiting 10 seconds")
        time.sleep(10)

    # not deleted after retries, bail out
    if project_exists(projname,globalvars) :
        raise RuntimeError("Failed to delete project " + projname)

def single_project(testconfig, projname, globalvars):
    globalvars["createproj"] = True
    if project_exists(projname,globalvars) :
        if testconfig["ifexists"] == "delete" :
            delete_project(projname,globalvars)
        elif testconfig["ifexists"] == "reuse" :
            globalvars["createproj"] = False
        else:
            logger.error("Project " + projname + " already exists. Use ifexists=reuse/delete in config")
            return

    if globalvars["createproj"]:
        if globalvars["kubeopt"]:
            tmpfile=tempfile.NamedTemporaryFile()
            with open("content/namespace-default.yaml") as infile:
                nsconfig = yaml.load(infile)
            nsconfig["metadata"]["name"] = projname
            with open(tmpfile.name, 'w+') as f:
                yaml.dump(nsconfig, f, default_flow_style=False)
            tmpfile.flush()
            oc_command("kubectl create -f %s" % tmpfile.name,globalvars)
            oc_command("kubectl label --overwrite namespace " + projname +" purpose=test", globalvars)
        else:
            if 'nodeselector' in testconfig:
                node_selector = " --node-selector=\"" + testconfig['nodeselector'] + "\""
                oc_command_with_retry("oc adm new-project " + projname + node_selector,globalvars)
            else:
                oc_command_with_retry("oc new-project --skip-config-write=true " + projname,globalvars)
            oc_command_with_retry("oc label --overwrite namespace " + projname +" purpose=test", globalvars)
    else:
        pass

    time.sleep(1)
    projenv={}

    if "tuningset" in globalvars:
        tuningset = globalvars["tuningset"]
    if "tuning" in testconfig:
        projenv["tuning"] = testconfig["tuning"]
    globalvars["curprojenv"] = projenv
    globalvars["namespace"] = projname
    if "quota" in testconfig:
        quota_handler(testconfig["quota"],globalvars)
    if "templates" in testconfig:
        template_handler(testconfig["templates"], globalvars)
    if "services" in testconfig:
        service_handler(testconfig["services"], globalvars)
    if "users" in testconfig:
        user_handler(testconfig["users"], globalvars)
    if "pods" in testconfig:
        if "pods" in tuningset:
            globalvars["tuningset"] = tuningset["pods"]
        pod_handler(testconfig["pods"], globalvars)
    if "rcs" in testconfig:
        rc_handler(testconfig["rcs"], globalvars)
    if globalvars["autogen"]:
        autogen_pod_handler(globalvars)

def autogen_pod_handler(globalvars):
   num_expected = int(globalvars["podnum"])
   pods_running = []
   pods_running = autogen_pod_wait(pods_running, num_expected)

   for pod in pods_running:
       rsync = subprocess.check_output(
               "oc rsync --namespace=%s /root/.ssh %s:/root/" \
               % (pod[0], pod[1]), shell=True)

   app = Flask(__name__)

   @app.route("/start")
   def hello():
       return "Hello"

   @app.route("/stop", methods=["POST"])
   def shutdown_server():
       func = request.environ.get("werkzeug.server.shutdown")
       if func is None:
           raise RuntimeError("Not running with the Werkzeug Server")
       func()

   def start_ws():
       app.run(host="0.0.0.0", port=9090, threaded=True)

   proc = Process(target=start_ws)
   proc.start()

   autogen_pod_wait(pods_running, 0)

   if proc.is_alive():
       proc.terminate()
       proc.join()

   logger.info("Load completed")

def autogen_pod_wait(pods_running, num_expected):
    while len(pods_running) != num_expected:
        pods_running = subprocess.check_output(
            "oc get pods --all-namespaces --selector=test --no-headers | "
            " awk '/1\/1/ && /Running/ {print $1,$2;}'", shell=True).splitlines()
        time.sleep(5)
    pods_running = [pod.split() for pod in pods_running]
    return pods_running

def project_handler(testconfig, globalvars):
    logger.debug("project_handler function called")

    total_projs = testconfig["num"]
    basename = testconfig["basename"]
    globalvars["env"] = []
    maxforks = globalvars["processes"]

    projlist = []
    i = 0
    while i < int(total_projs):
        j=0
        children = []
        while j < int(maxforks) and i < int(total_projs):
            j=j+1
            pid = os.fork()
            if pid:
                children.append(pid)
                i = i + 1
            else:
                projname = basename
                if "ifexists" not in testconfig:
                    logger.info("Parameter 'ifexists' not specified. Using 'default' value.")
                    testconfig["ifexists"] = "default"
                if testconfig["ifexists"] != "reuse" :
                    projname = basename + str(i)

                logger.info("forking %s"%projname)
                single_project(testconfig, projname, globalvars)
                os._exit(0)
        for k, child in enumerate(children):
            os.waitpid(child, 0)


def quota_handler(inputquota, globalvars):
    logger.debug("Function :: quota_handler")

    quota = globalvars["quota"]
    quotafile = quota["file"]
    if quotafile == "default":
        quotafile = "content/quota-default.json"

    with open(quotafile,'r') as infile:
        qconfig = json.load(infile)
    qconfig["metadata"]["namespace"] = globalvars["namespace"]
    qconfig["metadata"]["name"] = quota["name"]
    tmpfile=tempfile.NamedTemporaryFile()
    json.dump(qconfig,tmpfile)
    tmpfile.flush()
    if globalvars["kubeopt"]:
        oc_command("kubectl create -f " + tmpfile.name, globalvars)
    else:
        oc_command("oc create -f " + tmpfile.name, globalvars)
    tmpfile.close()


def template_handler(templates, globalvars):
    logger.debug("template_handler function called")

    logger.info("templates: %s", templates)
    for template in templates:
        num = int(template["num"])
        templatefile = template["file"]

        if "parameters" in template:
            parameters = template["parameters"]
        else:
            parameters = None
        if "tuningset" in globalvars:
            if "templates" in globalvars["tuningset"]:
                if "stepping" in globalvars["tuningset"]["templates"]:
                    globalvars["totaltemplates"] = 0

        create_template(templatefile, num, parameters, globalvars)

    if "totaltemplates" in globalvars:
        del (globalvars["totaltemplates"])


def service_handler(inputservs, globalvars):
    logger.debug("service_handler function called")

    namespace = globalvars["namespace"]
    globalvars["curprojenv"]["services"] = []

    for service in inputservs:
        num = int(service["num"])
        servfile = service["file"]
        basename = service["basename"]

        if servfile == "default":
            servfile = "content/service-default.json"

        service_config = {}
        with open(servfile) as stream:
            service_config = json.load(stream)
        service_config["metadata"]["namespace"] = namespace
        service_config["metadata"]["name"] = basename

        create_service(service_config, num, globalvars)


def ebs_create(globalvars):
    # just calling this function to create EBS, pv and pvc, EBS volume id == pv name == pvc name
    # names does not influence anything

    namespace = globalvars["namespace"]
    globalvars["curprojenv"]["services"] = []
    global ebsvolumeid
    ebsvolumeid = ec2_volume(ebsvolumesize,ebsvtype,ebstagprefix,ebsregion)
    with open("content/pv-default.json", "r") as pvstream:
        pvjson = json.load(pvstream)
    pvjson["metadata"]["name"] = ebsvolumeid
    pvjson["spec"]["capacity"]["storage"] = str(ebsvolumesize) + "Gi"  # this has to be like this till k8s 23357 is fixed
    pvjson["spec"]["accessModes"] = [pvpermissions]
    pvjson["spec"]["awsElasticBlockStore"]["volumeID"] = ebsvolumeid
    pvjson["spec"]["awsElasticBlockStore"]["fsType"] = fstype
    pvtmpfile = tempfile.NamedTemporaryFile(delete=True)
    json.dump(pvjson,open("pvebsexample.json", "w+"), sort_keys=True, indent=4, separators=(',', ': '))
    json.dump(pvjson,pvtmpfile,sort_keys=True, indent=4, separators=(',', ': '))
    pvtmpfile.flush()

    if globalvars["kubeopt"]:
        check = oc_command("kubectl create -f " + pvtmpfile.name, globalvars)
    else:
        check = oc_command("oc create -f " + pvtmpfile.name , globalvars)

    pvtmpfile.close()

    with open("content/pvc-default.json", "r") as pvcstream:
        pvcjson = json.load(pvcstream)
    pvcjson["metadata"]["name"] = ebsvolumeid
    pvcjson["metadata"]["namespace"] = namespace
    pvcjson["spec"]["resources"]["requests"]["storage"] = str(ebsvolumesize) + "Gi"
    pvcjson["spec"]["accessModes"] = [pvcpermissions]
    pvctmpfile = tempfile.NamedTemporaryFile(delete=True)
    json.dump(pvcjson, open("pvcebsexample.json", "w+"), sort_keys=True, indent=4, separators=(',', ': '))
    json.dump(pvcjson,pvctmpfile,sort_keys=True, indent=4, separators=(',', ': '))
    pvctmpfile.flush()
    if globalvars["kubeopt"]:
        check = oc_command("kubectl create -f " + pvctmpfile.name, globalvars)
        # why we have both kubectl and oc? kubectl will to all
    else:
        check = oc_command("oc create -f " + pvctmpfile.name, globalvars)
        pvctmpfile.close()

# this function creates CEPH secret
def ceph_secret_create(cephsecret,globalvars):
    namespace = globalvars["namespace"]
    with open("content/ceph-secret.json") as cephsec:
        cephsecjson = json.load(cephsec)

    cephsecjson["metadata"]["name"] = cephsecretname
    cephsecjson["metadata"]["namespace"] = namespace
    cephsecjson["data"]["key"] = cephsecret
    sectmpfile = tempfile.NamedTemporaryFile(delete=True)
    json.dump(cephsecjson, open("cephseckey.json", "w+"), sort_keys=True, indent=4, separators=(',', ': '))
    json.dump(cephsecjson, sectmpfile, sort_keys=True, indent=4, separators=(',', ': '))
    sectmpfile.flush()

    # create ceph sec
    if globalvars["kubeopt"]:
        check = oc_command("kubectl create -f " + sectmpfile.name, globalvars)
    else:
        check = oc_command("oc create -f " + sectmpfile.name, globalvars)
        sectmpfile.close()

# this function will create pv/pvc based on ceph image
def ceph_image_create(i,globalvars):
    """
    This function will prepare pv/pvc file for case when pods
    will use gluster volume for persistent storage
    """
    namespace = globalvars["namespace"]
    globalvars["curprojenv"]["services"] = []
    cephimagename = "cephimage" + str(i)
    imagesize = 1024**3*int(cephimagesize)

    # ceph_volume function will create ceph images at ceph storage cluster side
    ceph_volume(cephpool,cephimagename,imagesize)
    with open("content/pv-ceph.json") as pvstream:
        pvjson = json.load(pvstream)

    pvjson["metadata"]["name"] =  "cephvol" + str(i)
    pvjson["metadata"]["namespace"] = namespace
    pvjson["spec"]["capacity"]["storage"] = str(cephimagesize) + "Gi"  # this has to be like this till k8s 23357 is fixed
    pvjson["spec"]["accessModes"] = [pvpermissions]
    pvjson["spec"]["rbd"]["monitors"] = [x + str(":") + str(6789) for x in cephmonitors]
    pvjson["spec"]["rbd"]["pool"] = cephpool
    pvjson["spec"]["rbd"]["image"] = "cephimage" + str(i)
    pvjson["spec"]["rbd"]["user"] = "admin"
    pvjson["spec"]["rbd"]["secretRef"]["name"] = cephsecretname

    pvtmpfile = tempfile.NamedTemporaryFile(delete=True)
    json.dump(pvjson,open("pvcephexample.json", "w+"), sort_keys=True, indent=4, separators=(',', ': '))
    json.dump(pvjson,pvtmpfile,sort_keys=True, indent=4, separators=(',', ': '))
    pvtmpfile.flush()

    # create pv
    if globalvars["kubeopt"]:
        check = oc_command("kubectl create -f " + pvtmpfile.name, globalvars)
    else:
        check = oc_command("oc create -f " + pvtmpfile.name , globalvars)

    pvtmpfile.close()

    with open("content/pvc-default.json", "r") as pvcstream:
        pvcjson = json.load(pvcstream)
    pvcjson["metadata"]["name"] = "cephclaim" + str(i)
    pvcjson["metadata"]["namespace"] = namespace
    pvcjson["spec"]["resources"]["requests"]["storage"] = str(cephimagesize) + "Gi"
    pvcjson["spec"]["accessModes"] = [pvcpermissions]
    pvctmpfile = tempfile.NamedTemporaryFile(delete=True)
    json.dump(pvcjson, open("pvccephexample.json", "w+"), sort_keys=True, indent=4, separators=(',', ': '))
    json.dump(pvcjson,pvctmpfile,sort_keys=True, indent=4, separators=(',', ': '))
    pvctmpfile.flush()
    if globalvars["kubeopt"]:
        check = oc_command("kubectl create -f " + pvctmpfile.name, globalvars)
        # why we have both kubectl and oc? kubectl will to all
    else:
        check = oc_command("oc create -f " + pvctmpfile.name, globalvars)
        pvctmpfile.close()

# gluster_image_create and nfs_image_create will be added
"""
def gluster_image_create():
"""
"""
def nfs_image_create():
"""
def pod_handler(inputpods, globalvars):
    logger.debug("pod_handler function called")

    namespace = globalvars["namespace"]
    total_pods = int(inputpods[0]["total"])
    inputpods = inputpods[1:]
    storage = inputpods[0]["storage"]

    global storagetype,ebsvolumesize, ebsvtype, ebsregion, ebstagprefix, mountdir, \
    pvpermissions, pvcpermissions, nfsshare, nfsip, volumesize, glustervolume, \
    glusterip, cephpool , cephmonitors, cephimagesize, cephsecret, cephsecretname, fstype

    if storage[0]["type"] in ("none", "None", "n"):
        storagetype = storage[0]["type"]
        print ("If storage type is set to None, then pods will not have persistent storage")

    elif storage[0]["type"] in ("ebs", "EBS"):
        storagetype = storage[0]["type"]
        ebsvolumesize = storage[0]["ebsvolumesize"]
        ebsvtype = storage[0]["ebsvtype"]
        ebsregion = storage[0]["ebsregion"]
        ebstagprefix = storage[0]["ebstagprefix"]
        mountdir = storage[0]["mountdir"]
        fstype = storage[0]["fstype"]
        pvpermissions = storage[0]["pvpermissions"]
        pvcpermissions = storage[0]["pvcpermissions"]
        print ("Storage type EBS specified, ensure that OSE master/nodes are configured to reach EC2")

    elif storage[0]["type"] in ("nfs", "NFS"):
        storagetype = storage[0]["type"]
        nfsshare = storage[0]["nfsshare"]
        nfsip = storage[0]["nfsip"]
        mountdir = storage[0]["mountdir"]
        volumesize = storage[0]["volumesize"]
        fstype = storage[0]["fstype"]
        pvpermissions = storage[0]["pvpermissions"]
        pvcpermissions = storage[0]["pvcpermissions"]
        print ("NFS storage backend specified, ensure that access to NFS with ip", nfsip, "works properly")

    elif storage[0]["type"] in ("gluster", "GLUSTER"):
        storagetype = storage[0]["type"]
        glustervolume = storage[0]["glustervolume"]
        glusterip = storage[0]["glusterip"]
        mountdir = storage[0]["mountdir"]
        volumesize = storage[0]["volumesize"]
        fstype = storage[0]["fstype"]
        pvpermissions = storage[0]["pvpermissions"]
        pvcpermissions = storage[0]["pvcpermissions"]
        print ("Storage type Gluster specified, ensure access to Gluster servers", glusterip, "works properly")

    elif storage[0]["type"] in ("ceph", "CEPH"):
        storagetype = storage[0]["type"]
        cephpool = storage[0]["cephpool"]
        cephmonitors = storage[0]["cephmonitors"]
        cephimagesize = storage[0]["cephimagesize"]
        cephsecretname = storage[0]["cephsecretname"]
        cephsecret = storage[0]["cephsecret"]
        mountdir = storage[0]["mountdir"]
        fstype = storage[0]["fstype"]
        pvpermissions = storage[0]["pvpermissions"]
        pvcpermissions = storage[0]["pvcpermissions"]
        # if CEPH is specified, we have to create ceph secret on OSE master
        # before creating pv/pvc/pod, secrete needs to be created
        # only once , treating this as one time run variable
        ceph_secret_create(cephsecret,globalvars)
        print ("Storage type CEPH specified, ensure that OSE master is configured to reach CEPH cluster and ceph monitors", cephmonitors)


    globalvars["curprojenv"]["pods"] = []
    if "tuningset" in globalvars:
        globalvars["podtuningset"] = globalvars["tuningset"]

    globalvars["pend_pods"] = []
    if "podtuningset" in globalvars:
        if "stepping" in globalvars["podtuningset"]:
            globalvars["totalpods"] = 0

    for podcfg in inputpods:
        num = int(podcfg["num"]) * total_pods / 100
        podfile = podcfg["file"]
        basename = podcfg["basename"]
        if podfile == "default":
            podfile = "content/pod-default.json"

        pod_config = {}
        with open(podfile) as stream:
            pod_config = json.load(stream)
        pod_config["metadata"]["namespace"] = namespace
        pod_config["metadata"]["name"] = basename

        create_pods(pod_config, num,storagetype, globalvars)

    if globalvars["tolerate"] is False:
        if len(globalvars["pend_pods"]) > 0:
            pod_data(globalvars)

        if "podtuningset" in globalvars:
            del(globalvars["podtuningset"])
            del(globalvars["totalpods"])
        del(globalvars["pend_pods"])


def rc_handler(inputrcs, globalvars):
    logger.debug("rc_handler function called")

    namespace = globalvars["namespace"]
    globalvars["curprojenv"]["rcs"] = []
    for rc_cfg in inputrcs:
        num = int(rc_cfg["num"])
        replicas = int(rc_cfg["replicas"])
        rcfile = rc_cfg["file"]
        basename = rc_cfg["basename"]
        image = rc_cfg["image"]

        if rcfile == "default":
            rcfile = "content/rc-default.json"

        rc_config = {}
        with open(rcfile) as stream:
            rc_config = json.load(stream)
        rc_config["metadata"]["namespace"] = namespace
        rc_config["metadata"]["name"] = basename
        rc_config["spec"]["replicas"] = replicas
        rc_config["spec"]["template"]["spec"]["containers"][0]["image"] = image

        create_rc(rc_config, num,globalvars)


def user_handler(inputusers, globalvars):
    logger.info("user_handler function called")

    globalvars["curprojenv"]["users"] = []

    for user in inputusers:
        create_user(user, globalvars)


def find_tuning(tuningsets, name):
    for tuningset in tuningsets:
        if tuningset["name"] == name:
            return tuningset
        else:
            continue

    logger.error("Failed to find tuningset: " + name + " Exiting.....")
    sys.exit()


def find_quota(quotaset, name):
    for quota in quotaset:
        if quota["name"] == name:
            return quota
        else:
            continue

    logger.error("Failed to find quota : " + name + " Exitting ......")
    sys.exit()
