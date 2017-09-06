#!/usr/bin/env python
import subprocess, json, os, yaml, sys

from utils import *
from optparse import OptionParser

cliparser = OptionParser()

cliparser.add_option("-f", "--file", dest="cfgfile",
                     help="This is the input config file used to define the test.",
                     metavar="FILE", default="pyconfig.yaml")
cliparser.add_option("-c", "--certpath", dest="cert",
                     default="/etc/origin/master/ca.crt",
                     help="The certificate path to login a user.")
cliparser.add_option("-o", "--passfile", dest="osepassfile",
                     default="/etc/origin/openshift-passwd",
                     help="Path to openshift-passwd file to add user's password.", )
cliparser.add_option("-n", "--namespace", dest="projectname",
                     help="Project/Namespace under which to run the test",
                     default="testproj00")
cliparser.add_option("-m", "--master", dest="osemaster",
                     default="https://ose3-master.example.com:8443",
                     help="The Adress of the OSE Master")
cliparser.add_option("-u", "--user", dest="oseuser", default="user00",
                     help="OSE user under which to run the test")
cliparser.add_option("-s", "--password", dest="osepass", default="",
                     help="Password of user under which to run the test")
cliparser.add_option("-d", "--clean",
                     action="store_true", dest="cleanall", default=False,
                     help="Clean the openshift environment created by the test.")
cliparser.add_option("-v", "--debug",
                     action="store_true", dest="debug", default=False,
                     help="Prints more detailed info to help debug an issue.")
cliparser.add_option("-k", "--kube", dest="kube", default=False,
                     action="store_true",
                     help="Use kubectl instead of oc to create objects")
cliparser.add_option("--kubeconfig", dest="kubeconfig",
                     default=os.path.expanduser("~") + "/.kube/config",
                     help="Location of the default kubeconfig to use")
cliparser.add_option("-p", "--processes", dest="processes",
                     default="10",
                     help="The maximum number of concurrent processes used to create projects")
cliparser.add_option("-a", "--auto-gen",
                     action="store_true", dest="autogen", default=False,
                     help="Override config parameters with live OpenShift data.")
cliparser.add_option("-t", "--tolerate-bad-pods", action="store_true", default=False, dest="tolerate",
                     help="Tolerates bad pods, by default cluster loader cannot tolerate bad pods as \
                     it runs till all the pods come to running state.")

(options, args) = cliparser.parse_args()


testconfig = {}
with open(options.cfgfile) as stream:
    testconfig = yaml.load(stream)

globalvars = {}
globalvars["cleanoption"] = options.cleanall
globalvars["debugoption"] = options.debug
globalvars["kubeopt"] = options.kube
globalvars["env"] = []
globalvars["kubeconfig"] = options.kubeconfig
globalvars["processes"] = options.processes
globalvars["autogen"] = options.autogen
globalvars["podnum"] = 0
globalvars["tolerate"] = options.tolerate

user = options.oseuser
passwd = options.osepass
master = options.osemaster

if "quotas" in testconfig:
    globalvars["quotas"] = testconfig["quotas"]
    
if "tuningsets" in testconfig:
    globalvars["tuningsets"] = testconfig["tuningsets"]

if user and passwd and master:
    login = login(user, passwd, master)

globalvars["version_info"] = check_oc_version(globalvars)

for config in testconfig["projects"]:
    if "tuning" in config:
        globalvars["tuningset"] = find_tuning(testconfig["tuningsets"],\
            config["tuning"])

    if "quota" in config:
        globalvars["quota"] = find_quota(testconfig["quotas"],\
            config["quota"])

    project_handler(config,globalvars)

