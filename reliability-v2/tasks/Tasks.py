import logging
import random
from time import sleep
import requests
import sys
from threading import Lock
import asyncio
import string
import re
from tasks.GlobalData import global_data
from utils.cli import oc,kubectl,shell
from utils.LoadApp import loadApp
from integrations.SlackIntegration import slackIntegration
from concurrent.futures import ThreadPoolExecutor

netobserv_pods = {}

class Tasks:
    def __init__(self):
        self.logger = logging.getLogger('reliability')
        self.result_lock = Lock()
        self.results = {}
        self.kubeconfig_admin = ""
        self.__get_admin()

    def get_results(self):
        results = [f"{'[Function]'.ljust(25)}|{'Total'.rjust(10)}|{'Passed'.rjust(10)}|{'Failed'.rjust(10)}|{'Failure Rate'.rjust(10)}|"]
        results.append("-----------------------------------------------------------------------")
        for key,value in self.results.items():
            passed = value["passed"]
            failed = value["failed"]
            total = passed + failed
            failure_rate = '{:.1%}'.format(failed/total)
            function = f"[{key}]"
            results.append(f"{function.ljust(25)}|{str(total).rjust(10)}|{str(passed).rjust(10)}|{str(failed).rjust(10)}|{str(failure_rate).rjust(10)}|")
        results.append("-----------------------------------------------------------------------")
        results = "\n".join(results)
        self.logger.info(f"Reliability test results:\n"+ results)
        return results

    def __log_result(self,rc,name="func"):
        # func is the name of the caller function if name is not passed by the caller
        if name == "func":
            name = sys._getframe(1).f_code.co_name
        # set default if not already exist
        self.results.setdefault(name, {"passed":0,"failed":0})
            
        with self.result_lock:
            if rc == 0:
                self.results[name]["passed"] += 1
            else:
                self.results[name]["failed"] += 1

    def __get_admin(self):
        for key in global_data.kubeconfigs:
            if "admin" in key:
                self.kubeconfig_admin = global_data.kubeconfigs[key]
                break

    def __get_kubeconfig(self,user):
        kubeconfig = ""
        try:
            kubeconfig=global_data.kubeconfigs[user]
        except Exception as e :
            self.logger.error(f"Failed to find kubeconfig for user {user}. Exception: {e}")
        return kubeconfig

    # check namespace are deleted successfully
    def verify_project_deletion(self,user,namespace):
        self.logger.info(f"[Task] User {user}: verify project deletion '{namespace}'")
        retry = 10
        final_rc = 1
        while retry > 0:
            result,rc = oc(f"get project {namespace} --no-headers",self.kubeconfig_admin,ignore_log=True,ignore_slack=True)
            if "not found" in result and rc == 1:
                # issue during test: in about 1/10 cases, oc get project step gets no project, but
                # new_project step shows already exists or is being terminated. 
                # Sleep 20s can mitigate but not avoid this issue.
                sleep(20)
                final_rc = 0
                break
            else:
                self.logger.info(f"Verifying project deletion for project '{namespace}', last result: '{result}'. Retry left '{retry}'")
                sleep(20)
                retry -= 1
        if retry == 0:
            oc(f"get po -n {namespace}",self.kubeconfig_admin,ignore_slack=True)
        self.__log_result(final_rc)
        return (result,final_rc)

    # delete project in a namespace
    def delete_project(self,user,namespace):
        self.logger.info(f"[Task] User {user}: delete project '{namespace}'")
        (result,rc) = oc(f"delete project {namespace}",self.__get_kubeconfig(user))
        self.__log_result(rc)
        return (result,rc)

    # delete all project for a user
    def delete_all_projects(self,user):
        if "admin" in user:
            return ("admin user not allowed for delete_all_projects function.",1)
        self.logger.info(f"[Task] User {user}: delete all projects for user {user}")
        (result,rc) = oc(f"delete project --all",self.__get_kubeconfig(user))
        self.__log_result(rc)
        return (result,rc)

    # new a project
    def new_project(self,user,namespace):
        self.logger.info(f"[Task] User {user}: new project '{namespace}'")
        # Replaced the below lines of commented code by function verify_project_deletion. Will delete the below lines later.
        # retry = 5
        # while retry > 0:
        #     result,rc = oc(f"get project {namespace} --no-headers",self.kubeconfig_admin,ignore_log=True,ignore_slack=True)
        #     if "Terminating" in result:
        #         sleep(20)
        #         retry -= 1
        #     else:
        #         # issue during test: in about 1/10 cases, last step gets no project, but
        #         # next step shows already exists. Sleep 20s can mitigate but not avoid this issue.
        #         sleep(20)
        #         break
        (result,rc) = oc(f"new-project --skip-config-write {namespace}",self.__get_kubeconfig(user))
        if rc == 0:
            # developer is forbidden to patch resource "namespaces"
            oc(f"label namespace {namespace} purpose=reliability",self.kubeconfig_admin)
            group_name = namespace.split(f"-{user}")[0]
            oc(f"label namespace {namespace} group={group_name}",self.kubeconfig_admin)
        self.__log_result(rc)
        return (result,rc)

    # check all projects for a user
    def check_all_projects(self,user):
        self.logger.info(f"[Task] User {user}: check all projects for user {user}")
        (result,rc) = oc(f"get projects", self.__get_kubeconfig(user))
        self.__log_result(rc)
        return (result,rc)

    # pod tasks in a namespace
    def check_pods(self,user,namespace):
        self.logger.info(f"[Task] User {user}: check pods in namespace {namespace}")
        (result, rc) = oc(f"get pods -o wide -n {namespace}",self.__get_kubeconfig(user))
        #| egrep -v 'Running|Complete'
        self.__log_result(rc)
        return (result, rc)

    # new an app in a namespace
    def new_app(self,user,namespace):
        template = random.choice(global_data.config["appTemplates"])["template"]
        self.logger.info(f"[Task] User {user}: new app with tempate {template}")
        (result,rc) = oc(f"new-app -n {namespace} --template {template}",self.__get_kubeconfig(user))
        if rc != 0:
            self.__log_result(rc)
            return(result,rc)
        else:
            (route,rc) = oc(f"get route --no-headers -n {namespace} | awk {{'print $2'}} | grep {template}",self.__get_kubeconfig(user))
            if rc == 0 and "No resources found" not in route:
                route = route.rstrip()
                url = f"http://{route}:80"
                max_tries = 60
                current_tries = 0
                visit_success = False
                while not visit_success and current_tries <= max_tries:
                    self.logger.info(f"{template} route not available yet, sleeping 30 seconds. Retry:{current_tries}/{max_tries}.")
                    sleep(30)
                    current_tries += 1
                    visit_success,status_code = self.__visit_app(url)
                if not visit_success:
                    # debug the namespace
                    self.__get_namespace_resource(user,namespace,"pods")
                    self.__get_namespace_resource(user,namespace,"events")
                    # sleep 5 minutes for manual debug
                    self.logger.info(f"new_app: visit '{url}' failed after 30 minutes. status_code: {status_code}. Wait 5 more minutes for manual debug.")
                    slackIntegration.info(f"new_app: visit '{url}' failed after 30 minutes. status_code: {status_code}. Wait more 5 minutes for manual debug.")
                    sleep(300)
                    self.logger.error(f"new_app: visit '{url}' failed after 35 minutes. status_code: {status_code}")
                    slackIntegration.error(f"new_app: visit '{url}' failed after 35 minutes. status_code: {status_code}")
                    # return 1 so the upcoming tasks won't be run
                    self.__log_result(1)
                    return(visit_success,1)
                else:
                    self.__log_result(0)
            else:
                visit_success = False
                self.logger.error(f"new_app: get route failed for '{namespace}.{template}'.")
                slackIntegration.error(f"new_app: get route failed for '{namespace}.{template}'.")
                self.__log_result(1)
                return(visit_success,1)
            return(visit_success,0)

    # visit the given application route
    def __visit_app(self,url):
        visit_success = False
        try:
            r = requests.get(url, verify=False)
            if r.status_code != 200:
                self.logger.info(f"Response code:{str(r.status_code)}. Visit failed: {url}")
            if r.status_code == 200:
                self.logger.info(f"Response code:{str(r.status_code)}. Visit succeeded: {url}")
                visit_success = True
            return visit_success, r.status_code
        except Exception as e :
            self.logger.error(f"Visit exception: {url}. Exception: {e}")
            return visit_success, 0

    # load the route in the given namespace with 'clients' number of concurrent threads
    def load_app(self,user,namespace,clients="1"):
        (host,rc) = oc(f"get route --no-headers -n {namespace} | awk {{'print $2'}}",self.__get_kubeconfig(user))
        (termination,rc1) = oc(f"get route --no-headers -n {namespace} | awk {{'print $5'}}",self.__get_kubeconfig(user))
        if rc == 0 and "No resources found" not in host:
            host = host.rstrip()
            termination = termination.rstrip()
            url = f"http://{host}:80"
            if termination == "edge" or termination == "reencrypt" or termination == "passthrough":
                url = f"https://{host}:443"
            self.logger.info(f"[Task] load app route {url} in namespace {namespace} with {clients} clients.")
            urls = []
            for i in range(int(clients)):
                urls.append(url)
            with ThreadPoolExecutor(max_workers=int(clients)) as executor:
                results = executor.map(self.__visit_app, urls)
                return_value = 0
                for result in results:
                    # if any of the client visit fails, load_app func is marked as failed.
                    if result[0] == True:
                        self.__log_result(0)
                    if result[0] != True:
                        self.__log_result(1)
                        return_value = 1
                        status_code = result[1]
            if return_value == 1:
                self.logger.error(f"load_app: visit route '{url}' failed. status_code: {status_code}")
                slackIntegration.error(f"load_app: visit route '{url}' failed. status_code: {status_code}")
            return ("",return_value)
        else:
            self.logger.error(f"load_app: get route failed for namespace '{namespace}'.")
            slackIntegration.error(f"load_app: get route failed for namespace '{namespace}'.")
            return ("",1)

#when halt get the following: 
#for result in list(results[0]):
#TypeError: 'generator' object is not subscriptable
#Task was destroyed but it is pending!
#task: <Task pending name='Task-32' coro=<LoadApp.get() running at /Users/qili/git/svt/reliability-v2/utils/LoadApp.py:19> wait_for=<Future pending cb=[shield.<locals>._outer_done_callback() at /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.8/lib/python3.8/asyncio/tasks.py:902, <TaskWakeupMethWrapper object at 0x10b564c10>()]>>

    # def load_app(self,user,namespace,clients="1"):
    #     (route,rc) = oc(f"get route --no-headers -n {namespace} | awk {{'print $2'}}",self.__get_kubeconfig(user))
    #     route = route.rstrip()
    #     self.logger.info(f"[Task] load app in namespace {namespace} with {clients} clients.")
    #     urls = []
    #     urls.append(f"http://{route}/")
    #     loadApp.set_tasks(urls,int(clients))
    #     loop = asyncio.get_event_loop()
    #     try:
    #         results = loop.run_until_complete(asyncio.wait(loadApp.tasks))
    #     except Exception as e:
    #         self.logger.error(f"load_app Exception {e}")
    #     done = results[0]
    #     return_msg = "success"
    #     for result in list(done):
    #         if result.result() != 0:
    #             return_value = 1
    #             return_msg = "some visit failed to return 200"
    #             break
    #     self.__log_result(return_value)
    #     return (return_msg,return_value) 

    # start build a build config in a given namespace
    def build(self,user,namespace):
        (build_config,rc) = oc(f"get bc --no-headers -n {namespace}| awk {{'print $1'}}",self.__get_kubeconfig(user))
        self.logger.info(f"[Task] User {user}: build app in namespace {namespace} with build config '{build_config}'")
        (result,rc) = oc(f"start-build -n {namespace} {build_config}",self.__get_kubeconfig(user))
        self.__log_result(rc)
        return (result,rc)
    
    # scale the deployment config to given number of replicas in the given namespace
    def scale_deploymentconfig(self,user,namespace,replicas="1"):
        # 2>/dev/null to avoid Warning: apps.openshift.io/v1 DeploymentConfig is deprecated in v4.14+, unavailable in v4.10000+
        (deploymentconfig, rc) = oc(f"get dc --no-headers -n {namespace} 2>/dev/null | grep persistent | awk {{'print $1'}}",self.__get_kubeconfig(user))
        deploymentconfig = deploymentconfig.rstrip()
        self.logger.info(f"[Task] User {user}: scale deployment config'{deploymentconfig}' to '{replicas}' replicas")
        (result, rc) = oc(f"scale --replicas={replicas} -n {namespace} dc/{deploymentconfig}",self.__get_kubeconfig(user))
        if rc == 0:
            sleep(30)
            rc = self.__check_replicas(user,namespace,"dc",deploymentconfig,replicas)
        self.__log_result(rc)
        return (result,rc)
    
    # scale the deployment to given number of replicas in the given namespace
    def scale_deployment(self,user,namespace,replicas="1"):
        (deployment, rc) = oc(f"get deployment --no-headers -n {namespace} | grep -v client | awk {{'print $1'}}",self.__get_kubeconfig(user))
        deployment = deployment.rstrip()
        self.logger.info(f"[Task] User {user}: scale deployment'{deployment}' to '{replicas}' replicas")
        (result, rc) = oc(f"scale deployment --replicas={replicas} -n {namespace} {deployment}",self.__get_kubeconfig(user))
        if rc == 0:
            sleep(30)
            rc = self.__check_replicas(user,namespace,"deployment",deployment,replicas)
        self.__log_result(rc)
        return (result,rc)
    
    # check replica numbers of a given deployment in the given namespace
    def __check_replicas(self,user,namespace,object,name,replicas):
        # 2>/dev/null to avoid Warning: apps.openshift.io/v1 DeploymentConfig is deprecated in v4.14+, unavailable in v4.10000+
        (result, rc) = oc("get "+object+"/"+name+" -n "+namespace+" -o jsonpath='{.status.readyReplicas}' 2>/dev/null",self.__get_kubeconfig(user))
        max_tries = 10
        current_tries = 0
        while result != replicas and current_tries <= max_tries:
            self.logger.info(f"[Task] User {user}: check {object} '{name}' to reach '{replicas}' replicas. Current replica:{result}. Retry:{current_tries}/{max_tries}")
            (result, rc) = oc("get "+object+"/"+name+" -n "+namespace+" -o jsonpath='{.status.readyReplicas}' 2>/dev/null",self.__get_kubeconfig(user))
            sleep(30)
            current_tries += 1
        if result != replicas:
            # debug the namespace
            self.__get_namespace_resource(user,namespace,object)
            self.__get_namespace_resource(user,namespace,"events")
            return(1)
        else:
            return(0)
        
    # oc apply a file
    def apply(self,user,namespace,parameter):
        self.logger.info(f"[Task] apply file {parameter} in namespace {namespace}.")
        (result, rc) = oc(f"apply -f {parameter} -n {namespace}",self.__get_kubeconfig(user))
        self.__log_result(rc)
        return (result,rc)
    
    # oc apply a file
    def apply_nonamespace(self,user,parameter):
        self.logger.info(f"[Task] apply file {parameter} without namespace.")
        (result, rc) = oc(f"apply -f {parameter}",self.__get_kubeconfig(user))
        self.__log_result(rc)
        return (result,rc)

    # admin tasks
    # check if the operators are all healthy
    def check_operators(self,user):
        # This operation can only be done by admin user
        self.logger.info(f"[Task] User {user}: check operators")
        # Headers AVAILABLE   PROGRESSING   DEGRADED
        # Check if operators are progressing
        (result,rc) = oc(f"get co --no-headers| grep 'True.*True.*False'",self.__get_kubeconfig(user),ignore_log=True,ignore_slack=True)
        if rc == 0 :
            self.logger.info(f"Operator progressing: {result}")
            slackIntegration.info(f"Operator progressing: {result}")
            rc_return = 0
        elif rc == 1 and result == "":
            rc_return = 0
        else:
            rc_return = 1
        # Check if operators are unavailable or degraded
        # filter out insights operator as it is degraded on ocm staging env as expected
        (result,rc) = oc(f"get co --no-headers| grep -v insights | grep -v 'True.*[True|False].*False'",self.__get_kubeconfig(user),ignore_log=True,ignore_slack=True)
        if rc == 1 and result == "":
            self.logger.info(f"Cluster operators are healthy.")
            rc_return = 0
        elif rc == 0 :
            self.logger.error(f"Operator unavailable or degraded: {result}")
            slackIntegration.error(f"Operator unavailable or degraded: {result}")
            rc_return = 1
        else:
            rc_return = 1
        self.__log_result(rc_return)
        return(result,rc_return)
    
    # check if the nodes are all Ready
    def check_nodes(self,user):
        self.logger.info(f"[Task] User {user}: check nodes")
        # Check if nodes are Ready
        (result,rc) = oc(f"get nodes --no-headers| grep -v ' Ready'",self.__get_kubeconfig(user),ignore_log=True,ignore_slack=True)
        if rc == 0:
            self.logger.error(f"Some nodes are not Ready: {result}")
            slackIntegration.error(f"Some nodes are not Ready: {result}")
            rc_return = 1
        elif rc == 1 and result == "":
            self.logger.info(f"Nodes are healthy.")
            rc_return = 0
        else:
            self.logger.error(f"Check node failed: {result}")
            slackIntegration.error(f"Check node failed: {result}")
            rc_return = 1
        return(result,rc_return)

    # oc get the given type of resource in the given namespace
    def __get_namespace_resource(self,user,namespace,type):
        (result,rc) = oc(f"get {type} -n {namespace}",self.__get_kubeconfig(user))
        return (result,rc)

    # oc create secret
    def __create_secret(self,user,namespace,type,name,path):
        self.logger.info(f"[Task] create secret in namespace {namespace}.")
        (result, rc) = oc(f"create secret {type} {name} --cert={path}/tls.crt --key={path}/tls.key -n {namespace}",self.__get_kubeconfig(user))        
        self.__log_result(rc)
        return (result,rc)

    # oc create role
    def __create_role(self,user,namespace,name,verb,resource,resourcename):
        self.logger.info(f"[Task] create role in namespace {namespace}.")
        (result, rc) = oc(f"create role {name} --verb={verb} --resource={resource} --resource-name={resourcename} -n {namespace}",self.__get_kubeconfig(user))
        self.__log_result(rc)
        return (result,rc)
    
    # oc create rolebinding
    def __create_rolebinding(self,user,namespace,name,role,serviceaccount):
        self.logger.info(f"[Task] create rolebinding in namespace {namespace}.")
        (result, rc) = oc(f"create rolebinding {name} --role={role} --serviceaccount={serviceaccount} -n {namespace}",self.__get_kubeconfig(user))        
        self.__log_result(rc)
        return (result,rc)
    
    # oc create secret
    def enable_route_external_cert(self,user,namespace,parameter):
        self.logger.info(f"[Task] create secret, role, rolebinding for edge route external certification in namespace {namespace}.")
        (result,rc) = self.__create_secret(user,namespace,"tls","edge-external-cert",parameter)
        (result,rc) = self.__create_role(user,namespace,"secret-reader","get,list,watch","secrets","edge-external-cert")
        (result,rc) = self.__create_rolebinding(user,namespace,"secret-reader-binding","secret-reader","openshift-ingress:router")
        self.__log_result(rc)
        return (result,rc)  
    
    # run oc cli type of task
    def oc_task(self,task,user):
        (result, rc) = oc(task,self.__get_kubeconfig(user))
        self.__log_result(rc)
        return (result,rc)

    # run kubectl type of task
    def kubectl_task(self,task,user):
        (result, rc) = kubectl(task,self.__get_kubeconfig(user))
        self.__log_result(rc)
        return (result,rc)

    # run shell script type of task
    def shell_task(self,task,user,group_name):
        # pass kubeconfig, user and group name to the shell task
        # kubeconfig, user and group name will be exported as env variables to the shell script
        (result, rc) = shell(task, self.__get_kubeconfig(user), user, group_name)
        # drop the path, only use the shell file name as the task name
        start_index=task.rfind('/')
        if start_index == -1:
            task_name=task
        else:
            task_name=task[start_index+1:]
        self.__log_result(rc,task_name)
        return (result,rc)
    
    # check flowcollector status for netobserv
    def check_flowcollector(self, user):
        self.logger.info(f"[Task] User {user}: check flowcollector")
        # Check if flowcollector is Ready
        (result, rc) = oc(
            f"get flowcollector --no-headers| grep -v 'Ready'",
            self.__get_kubeconfig(user),
            ignore_log=True,
            ignore_slack=True,
        )
        if rc == 0:
            self.logger.error(f"Flowcollector is not Ready: {result}")
            slackIntegration.error(f"Flowcollector not Ready: {result}")
            rc_return = 1
        elif rc == 1 and result == "":
            self.logger.info(f"Flowcollector is Ready.")
            rc_return = 0
        else:
            self.logger.error(f"Flowcollector status fetch error: result {result}, rc - {rc}")
            rc_return = 1
        self.__log_result(rc)
        return (result, rc_return)

    # check netobserv pods health
    def check_netobserv_pods(self, user):
        self.logger.info(f"[Task] User {user}: check netobserv pods")
        # Check if pods are Running
        for ns in ("netobserv", "netobserv-privileged"):
            (result, rc) = oc(
                f"get pods -n {ns} -o wide --no-headers| grep -v 'Running'",
                self.__get_kubeconfig(user),
                ignore_log=True,
                ignore_slack=True,
            )
            if rc == 0:
                self.logger.error(f"Some pods are not Ready in {ns} ns: {result}")
                slackIntegration.error(f"Some pods are not Ready in ns {ns}: {result}")
                rc_return = 1
            elif rc == 1 and result == "":
                self.logger.info(f"Pods in ns {ns} are healthy.")
                rc_return = 0
            else:
                self.logger.error(f"Pods status fetch error: result {result}, rc - {rc}")
                rc_return = 1
        self.__log_result(rc)
        return (result, rc_return)
    
    # check netobserv pod restarts
    def check_netobserv_pod_restarts(self, user):
        self.logger.info(f"[Task] User {user}: check netobserv pod restarts")
        pod_entry_regex = re.compile("(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?).*.*")
        for ns in ("netobserv", "netobserv-privileged", "openshift-netobserv-operator"):
            (result, rc) = oc(f"get pods -n {ns} --no-headers -o wide",self.__get_kubeconfig(user),ignore_log=True,ignore_slack=True)
            if rc == 0:
                pod_info_list = result.split('\n')
                for pod_info in pod_info_list:
                    pod_entry_parse = pod_entry_regex.search(pod_info)
                    if pod_entry_parse:
                        pod_restarts = int(pod_entry_parse.group(4))
                        pod_name = pod_entry_parse.group(1)
                        if pod_restarts > 0 and pod_name not in netobserv_pods:
                            self.logger.info(f"New pod {pod_name} in namespace {ns} has restarted {pod_restarts} times")
                            slackIntegration.info(f"New pod {pod_name} in namespace {ns} has restarted {pod_restarts} times")
                            netobserv_pods.update({pod_name:pod_restarts})
                        elif pod_name in netobserv_pods and pod_restarts > netobserv_pods[pod_name]:
                            self.logger.error(f"Pod {pod_name} in namespace {ns} has restarted {pod_restarts} times")
                            slackIntegration.info(f"Pod {pod_name} in namespace {ns} has restarted {pod_restarts} times")
                            netobserv_pods[pod_name] = pod_restarts
                    elif pod_info != '':       
                        self.logger.error("Could not parse oc get pods output: " + pod_info)
                        rc_return = 1
                rc_return = 0
            else:
                self.logger.error("oc get pods failed with rc: " + str(rc))
                rc_return = 1
        self.__log_result(rc)
        return (netobserv_pods, rc_return)
