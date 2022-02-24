import logging
import random
from time import sleep
import requests
import sys
from threading import Lock
import asyncio
from tasks.GlobalData import global_data
from utils.cli import oc,kubectl,shell
from utils.LoadApp import loadApp
from integrations.SlackIntegration import slackIntegration
from concurrent.futures import ThreadPoolExecutor

class Tasks:
    def __init__(self):
        self.logger = logging.getLogger('reliability')
        self.result_lock = Lock()
        self.results = {}

    def get_results(self):
        results = [f"{'[Function]'.ljust(25)}|{'Total'.rjust(10)}|{'Passed'.rjust(10)}|{'Failed'.rjust(10)}|"]
        results.append("-----------------------------------------------------------")
        for key,value in self.results.items():
            passed = value["passed"]
            failed = value["failed"]
            total = passed + failed
            function = f"[{key}]"
            results.append(f"{function.ljust(25)}|{str(total).rjust(10)}|{str(passed).rjust(10)}|{str(failed).rjust(10)}|")
        results.append("-----------------------------------------------------------")
        results = "\n".join(results)
        self.logger.info(f"Reliability test results:\n"+ results)
        return results

    def __log_result(self,rc):
        # func is the name of the caller function
        func = sys._getframe(1).f_code.co_name
        # set default if not already exist
        self.results.setdefault(func, {"passed":0,"failed":0})
            
        with self.result_lock:
            if rc == 0:
                self.results[func]["passed"] += 1
            else:
                self.results[func]["failed"] += 1
                    
    # delete all project for a user
    def delete_all_projects(self,user):
        if user == "kubeadmin":
            return ("admin user not allowed.",1)
        kubeconfig = global_data.kubeconfigs[user]
        self.logger.info(f"[Task] User {user}: delete all projects for user {user}")
        (result,rc) = oc(f"delete project --all",kubeconfig)
        self.__log_result(rc)
        return (result,rc)

    # new a project
    def new_project(self,user,namespace):
        kubeconfig_admin = global_data.kubeconfigs["kubeadmin"]
        kubeconfig = global_data.kubeconfigs[user]
        self.logger.info(f"[Task] User {user}: new project '{namespace}'")
        retry = 5
        while retry > 0:
            result,rc = oc(f"get project {namespace} --no-headers",kubeconfig_admin,ignore_log=True,ignore_slack=True)
            if "Terminating" in result:
                sleep(20)
                retry -= 1
            else:
                # issue during test: in about 1/10 cases, last step gets no project, but
                # next step shows already exists. Sleep 20s can mitigate but not avoid this issue.
                sleep(20)
                break
        (result,rc) = oc(f"new-project --skip-config-write {namespace}",kubeconfig)
        if rc == 0:
            # developer is forbidden to patch resource "namespaces"
            oc(f"label namespace {namespace} purpose=reliability",kubeconfig_admin)
        self.__log_result(rc)
        return (result,rc)

    # check all projects for a user
    def check_all_projects(self,user):
        kubeconfig = global_data.kubeconfigs[user]
        self.logger.info(f"[Task] User {user}: check all projects for user {user}")
        (result,rc) = oc(f"get projects", kubeconfig)
        self.__log_result(rc)
        return (result,rc)

    # delete project in a namespace
    def delete_project(self,user,namespace):
        kubeconfig = global_data.kubeconfigs[user]
        self.logger.info(f"[Task] User {user}: delete project '{namespace}'")
        (result,rc) = oc(f"delete project {namespace}",kubeconfig)
        self.__log_result(rc)
        return (result,rc)

    # pod tasks in a namespace
    def check_pods(self,user,namespace):
        kubeconfig = global_data.kubeconfigs[user]
        self.logger.info(f"[Task] User {user}: check pods in namespace {namespace}")
        (result, rc) = oc(f"get pods -o wide -n {namespace}",kubeconfig)
        #| egrep -v 'Running|Complete'
        self.__log_result(rc)
        return (result, rc)

    # new an app in a namespace
    def new_app(self,user,namespace):
        kubeconfig = global_data.kubeconfigs[user]
        template = random.choice(global_data.config["appTemplates"])["template"]
        self.logger.info(f"[Task] User {user}: new app with tempate {template}")
        (result,rc) = oc(f"new-app -n {namespace} --template {template}",kubeconfig)
        if rc != 0:
            self.__log_result(rc)
            return(result,rc)
        else:
            (route,rc) = oc(f"get route --no-headers -n {namespace} | awk {{'print $2'}} | grep {template}",kubeconfig)
            if rc == 0:
                route = route.rstrip()
                max_tries = 60
                current_tries = 0
                visit_success = False
                while not visit_success and current_tries <= max_tries:
                    self.logger.info(f"{template} route not available yet, sleeping 10 seconds") 
                    sleep(20)
                    current_tries += 1
                    visit_success = self.__visit_app(route)
                if not visit_success:
                    self.logger.error(f"add_app: {namespace}.{template} did not become available" )
            else:
                visit_success = False
            self.__log_result(rc)
            return(visit_success,0)

    def __visit_app(self,route):
        visit_success = False
        try:
            r = requests.get(f"http://{route}/")
            if r.status_code != 200:
                self.logger.info(f"Response code:{str(r.status_code)}. Visit failed: {route}")
            if r.status_code == 200:
                self.logger.info(f"Response code:{str(r.status_code)}. Visit succeeded: {route}")
                visit_success = True
        except Exception as e :
            self.logger.error(f"Visit exception: {route}. Exception: {e}")
        return visit_success

    def load_app(self,user,namespace,clients="1"):
        kubeconfig = global_data.kubeconfigs[user]
        (route,rc) = oc(f"get route --no-headers -n {namespace} | awk {{'print $2'}}",kubeconfig)
        route = route.rstrip()
        self.logger.info(f"[Task] load app route {route} in namespace {namespace} with {clients} clients.")
        urls = []
        for i in range(int(clients)):
            urls.append(route)
        with ThreadPoolExecutor() as executor:
            results = executor.map(self.__visit_app, urls)
            return_value = 0
            for result in results:
                # if any of the client visit fails, load_app func is marked as failed.
                if result == True:
                    self.__log_result(0)
                if result != True:
                    self.__log_result(1)
                    return_value = 1
        return ("",return_value)

#when halt get the following: 
#for result in list(results[0]):
#TypeError: 'generator' object is not subscriptable
#Task was destroyed but it is pending!
#task: <Task pending name='Task-32' coro=<LoadApp.get() running at /Users/qili/git/svt/reliability-v2/utils/LoadApp.py:19> wait_for=<Future pending cb=[shield.<locals>._outer_done_callback() at /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.8/lib/python3.8/asyncio/tasks.py:902, <TaskWakeupMethWrapper object at 0x10b564c10>()]>>

    # def load_app(self,user,namespace,clients="1"):
    #     kubeconfig = global_data.kubeconfigs[user]
    #     (route,rc) = oc(f"get route --no-headers -n {namespace} | awk {{'print $2'}}",kubeconfig)
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

    def build(self,user,namespace):
        kubeconfig = global_data.kubeconfigs[user]
        (build_config,rc) = oc(f"get bc --no-headers -n {namespace}| awk {{'print $1'}}",kubeconfig)
        self.logger.info(f"[Task] User {user}: build app in namespace {namespace} with build config '{build_config}'")
        (result,rc) = oc(f"start-build -n {namespace} {build_config}",kubeconfig)
        self.__log_result(rc)
        return (result,rc)

    def scale_up(self,user,namespace):
        kubeconfig = global_data.kubeconfigs[user]
        (build_config,rc) = oc(f"get bc --no-headers -n {namespace} | awk {{'print $1'}}",kubeconfig)
        deployment = build_config
        self.logger.info(f"[Task] User {user}: scale up deployment '{deployment}'")
        (result, rc) = oc(f"scale --replicas=2 -n {namespace} dc/{deployment}",kubeconfig)
        self.__log_result(rc)
        return (result,rc)
    
    def scale_down(self,user,namespace):
        kubeconfig = global_data.kubeconfigs[user]
        (build_config, rc) = oc(f"get bc --no-headers -n {namespace} | awk {{'print $1'}}",kubeconfig)
        deployment = build_config
        self.logger.info(f"[Task] User {user}: scale down deployment '{deployment}'")
        (result, rc) = oc(f"scale --replicas=1 -n {namespace} dc/{deployment}",kubeconfig)
        self.__log_result(rc)
        return (result,rc)

    def apply(self,user,namespace,file):
        kubeconfig = global_data.kubeconfigs[user]
        self.logger.info(f"[Task] apply file {file} in namespace {namespace}.")
        (result, rc) = oc(f"apply -f {file} -n {namespace}",kubeconfig)
        self.__log_result(rc)
        return (result,rc)

    # admin tasks
    def check_operators(self,user):
        # This operation can only be done by admin user
        kubeconfig = global_data.kubeconfigs[user]
        self.logger.info(f"[Task] User {user}: check operators")
        (result,rc) = oc(f"get co --no-headers | awk '{{print $1 $3 $4 $5 $7}}' | grep -v TrueFalseFalse",kubeconfig,ignore_log=True,ignore_slack=True)
        if rc == 1 and result == "":
            self.logger.info(f"Cluster operators are healthy.")
            rc_return = 0
        elif rc == 0 :
            self.logger.error(f"Operator degraded: {result}")
            slackIntegration.error(f"Operator degraded: {result}")
            rc_return = 1
        self.__log_result(rc_return)
        return(result,rc_return)

    def oc_task(self,task,user):
        kubeconfig = global_data.kubeconfigs[user]
        (result, rc) = oc(task,kubeconfig)
        self.__log_result(rc)
        return (result,rc)

    def kubectl_task(self,task,user):
        kubeconfig = global_data.kubeconfigs[user]
        (result, rc) = kubectl(task,kubeconfig)
        self.__log_result(rc)
        return (result,rc)

    def shell_task(self,task):
        (result, rc) = shell(task)
        self.__log_result(rc)
        return (result,rc)

