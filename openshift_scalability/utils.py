#!/usr/bin/env python

import json, subprocess, time, copy, sys, os, yaml, tempfile, shutil
from datetime import datetime
from clusterloaderstorage import *

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
        print "Invalid delay in rate_limit\nExitting ........"
        sys.exit()


def oc_command(args, globalvars):
    tmpfile=tempfile.NamedTemporaryFile()
    # see https://github.com/openshift/origin/issues/7063 for details why this is done. 
    shutil.copyfile(globalvars["kubeconfig"], tmpfile.name)
    ret = subprocess.check_output("KUBECONFIG="+tmpfile.name+" "+args, shell=True)
    if globalvars["debugoption"]:
        print args
    if args.find("oc process") == -1:
        print ret 
    tmpfile.close()
    return ret

def login(user,passwd,master):
    return subprocess.check_output("oc login --insecure-skip-tls-verify=true -u " + user + " -p " + passwd + " " + master,shell=True)


def create_template(templatefile, num, parameters, globalvars):
    if globalvars["debugoption"]:
        print "create_template function called"

    namespace = globalvars["namespace"]
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
                    cmdstring += " -v %s=%s" % (key, value)
        cmdstring += " -v IDENTIFIER=%i" % i

        processedstr = oc_command(cmdstring, globalvars)
        templatejson = json.loads(processedstr)
        json.dump(templatejson, tmpfile)
        tmpfile.flush()
        if globalvars["kubeopt"]:
            check = oc_command("kubectl create -f "+tmpfile.name + \
                " --namespace %s" % namespace, globalvars)
        else:
            check = oc_command("oc create -f "+ tmpfile.name + \
                " --namespace %s" % namespace, globalvars)
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


def create_service(servconfig, num, globalvars):
    if globalvars["debugoption"]:
        print "create_service function called"

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
    if globalvars["debugoption"]:
        print "create_pods function called"

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
                if total_pods_created % stepsize == 0:
                    pod_data(globalvars)
                    time.sleep(calc_time(pause))
            if "rate_limit" in globalvars["tuningset"]:
                delay = globalvars["tuningset"]["rate_limit"]["delay"]
                time.sleep(calc_time(delay))

        i = i + 1
        del (datapod)
        tmpfile.close()


def pod_data(globalvars):
    if globalvars["debugoption"]:
        print "pod_data function called"

    pend_pods = globalvars["pend_pods"]
    namespace = globalvars["namespace"]

    while len(pend_pods) > 0:
        if globalvars["kubeopt"]:
            getpods = oc_command("kubectl get pods --namespace " + namespace, globalvars)
        else:
            getpods = oc_command("oc get pods -n " + namespace, globalvars)
        all_status = getpods.split("\n")

        size = len(all_status)
        all_status = all_status[1:size - 1]
        for status in all_status:
            fields = status.split()
            if fields[2] == "Running" and fields[0] in pend_pods:
                pend_pods.remove(fields[0])
        time.sleep(10)


def create_rc(rc_config, num, globalvars):
    if globalvars["debugoption"]:
        print "create_rc function called"

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
    if globalvars["debugoption"]:
        print "create_user function called"

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
        oc_command("oadm policy add-role-to-user " + role + " " + name + \
                        " -n " + namespace, globalvars)
        print "Created User: " + name + " :: " + "Project: " + namespace + \
              " :: " + "role: " + role
        i = i + 1


def project_exists(projname, globalvars) :
    exists = False
    try :
        cmd = "kubectl" if globalvars["kubeopt"] else "oc"
        output = oc_command(cmd + " get project -o name " + projname, globalvars).rstrip()
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
        print "Project " + projname + " still exists, waiting 10 seconds"
        time.sleep(10)

    # not deleted after retries, bail out
    if project_exists(projname,globalvars) :
        raise RuntimeError("Failed to delete project " + projname)

def single_project(testconfig, projname, globalvars):
    if project_exists(projname,globalvars) :
        if globalvars["forcedelete"] :
            delete_project(projname,globalvars)
        else :
            print "ERROR: Project " + projname + " already exists.  Use -x option to force deletion"
            return

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
        oc_command("oc new-project " + projname,globalvars)      
        oc_command("oc label --overwrite namespace " + projname +" purpose=test", globalvars)
    
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


def project_handler(testconfig, globalvars):
    if globalvars["debugoption"]:
        print "project_handler function called"

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
                projname = basename + str(i)
                print "forking %s"%projname
                single_project(testconfig, projname, globalvars)
                os._exit(0)
        for k, child in enumerate(children):
            os.waitpid(child, 0)


def quota_handler(inputquota, globalvars):
    if globalvars["debugoption"]:
        print "Function :: quota_handler"

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
    if globalvars["debugoption"]:
        print "template_handler function called"

    print "templates: ", templates
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
    if globalvars["debugoption"]:
        print "service_handler function called"

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
    will use gluster volume for persistant storage
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
    if globalvars["debugoption"]:
        print "pod_handler function called"

    namespace = globalvars["namespace"]
    total_pods = int(inputpods[0]["total"])
    inputpods = inputpods[1:]
    storage = inputpods[0]["storage"]

    global storagetype,ebsvolumesize, ebsvtype, ebsregion, ebstagprefix, mountdir, \
    pvpermissions, pvcpermissions, nfsshare, nfsip, volumesize, glustervolume, \
    glusterip, cephpool , cephmonitors, cephimagesize, cephsecret, cephsecretname, fstype 

    if storage[0]["type"] in ("none", "None", "n"):
        storagetype = storage[0]["type"]
        print ("If storage type is set to None, then pods will not have persistant storage")

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

    if len(globalvars["pend_pods"]) > 0:
        pod_data(globalvars)

    if "podtuningset" in globalvars:
        del(globalvars["podtuningset"])
        del(globalvars["totalpods"])
    del(globalvars["pend_pods"])
    

def rc_handler(inputrcs, globalvars):
    if globalvars["debugoption"]:
        print "rc_handler function called"

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
    if globalvars["debugoption"]:
        print "user_handler function called"

    globalvars["curprojenv"]["users"] = []

    for user in inputusers:
        create_user(user, globalvars)


def clean_all(globalvars):
    if globalvars["debugoption"]:
        print "clean_all function called"

    with open("current_environment.json","r") as infile:
        environment = json.load(infile)

    for project in environment:
        globalvars["namespace"] = project["name"]
        if "tuning" in project:
            globalvars["tuning"] = True
            globalvars["tuningset"] = find_tuning(globalvars["tuningsets"],\
                project["tuning"])
#        if "templates" in project:
#            clean_templates(project["templates"],globalvars)
        if "services" in project:
            clean_services(project["services"], globalvars)
        if "pods" in project:
            clean_pods(project["pods"], globalvars)
        if "rcs" in project:
            clean_rcs(project["rcs"], globalvars)
        if "users" in project:
            clean_users(project["users"], globalvars)
        if "quota" in project:
            clean_quotas(project["quota"], globalvars)

        if globalvars["kubeopt"]:
            oc_command("kubectl delete project " + project["name"], globalvars)
        else:
            oc_command("oc delete project " + project["name"], globalvars)


#def clean_templates(templates,globalvars):
#    print "Cleaning all templates!!"
#    for template in templates:
#        data = {}
#        num = len(templates)
#        i = 0
#        while i < int(num):
#            tmpfile=tempfile.NamedTemporaryFile()
#            templatejson = copy.deepcopy(data)
#            cmdstring = "oc process -f %s" % templatefile
#            for parameter in parameters:
#                for key, value in parameter.iteritems():
#                    cmdstring += " -v %s=%s" % (key, value)
#                cmdstring += " -v IDENTIFIER=%i" % i
#
#            processedstr = oc_command(cmdstring, globalvars)
#            templatejson = json.loads(processedstr)
#            json.dump(templatejson, tmpfile)
#            tmpfile.flush()
#            if globalvars["kubeopt"]:
#                oc_command("kubectl delete -f "+ tmpfile.name, globalvars)
#            else:
#                oc_command("oc delete -f "+ tmpfile.name, globalvars)
#            tmpfile.close()


def clean_services(services, globalvars):
    for service in services:
        if globalvars["kubeopt"]:
            oc_command("kubectl delete service " + service + " --namespace " + \
                globalvars["namespace"], globalvars)
        else:
            oc_command("oc delete service " + service + " -n " + \
                globalvars["namespace"], globalvars)


def clean_pods(pods, globalvars):
    if "tuningset" in globalvars:
        if "pods" in globalvars["tuningset"]:
            globalvars["podtuningset"] = globalvars["tuningset"]["pods"]
    if "podtuningset" in globalvars:
        if "stepping" in globalvars["podtuningset"]:
            step = 0
            pend_pods = []
            pause = globalvars["podtuningset"]["stepping"]["pause"]
            stepsize = globalvars["podtuningset"]["stepping"]["stepsize"]
    for pod in pods:
        if "podtuningset" in globalvars:
            if "stepping" in globalvars["podtuningset"]:
                pend_pods.append(pod)
                if step >= stepsize:
                    delete_pod(pend_pods,globalvars)
                    step = 0
                    time.sleep(calc_time(pause))
                step = step + 1
            if "rate_limit" in globalvars["podtuningset"]:
                delay = globalvars["podtuningset"]["rate_limit"]["delay"]
                time.sleep(calc_time(delay))

        if globalvars["kubeopt"]:
            oc_command("kubectl delete pod " + pod + " --namespace " + \
                globalvars["namespace"], globalvars)
        else:
            oc_command("oc delete pod " + pod + " -n " + \
                globalvars["namespace"], globalvars)


def clean_rcs(rcs, globalvars):
    for rc in rcs:
        if globalvars["kubeopt"]:
            oc_command("kubectl delete rc " + rc + " --namespace " + \
                globalvars["namespace"], globalvars)
        else:
            oc_command("oc delete rc " + rc + " -n " + \
                globalvars["namespace"], globalvars)


def clean_users(users, globalvars):
    for user in users:
        if globalvars["kubeopt"]:
            oc_command("kubectl delete user " + user + " --namespace " +\
                globalvars["namespace"], globalvars)
        else:
            oc_command("oc delete user " + user + " -n " + \
                globalvars["namespace"], globalvars)


def clean_quotas(quota, globalvars):
    if globalvars["kubeopt"]:
        oc_command("kubectl delete quota " + quota + " --namespace " +\
            globalvars["namespace"], globalvars)
    else:
        oc_command("oc delete quota " + quota + " -n " +\
            globalvars["namespace"], globalvars)


def delete_pod(podlist,globalvars):
    namespace = globalvars["namespace"]
    
    while len(podlist) > 0 :
        if globalvars["kubeopt"]:
            getpods = oc_command("kubectl get pods --namespace " +\
                namespace, globalvars )
        else:   
            getpods = oc_command("oc get pods -n " + namespace,\
            globalvars )
        all_status = getpods.split("\n")
        all_status = filter(None, all_status)
        plist = []
        for elem in all_status[1:]:
            elemlist = elem.split()
            if elemlist[0] in podlist:
                podlist.remove(elemlist[0])
            else:
                continue
        time.sleep(5)


def find_tuning(tuningsets, name):
    for tuningset in tuningsets:
        if tuningset["name"] == name:
            return tuningset
        else:
            continue

    print "Failed to find tuningset: " + name + "\nExiting....."
    sys.exit()

def find_quota(quotaset, name):
    for quota in quotaset:
        if quota["name"] == name:
            return quota
        else:
            continue

    print "Failed to find quota : " + name + "\nExitting ......"
    sys.exit()
