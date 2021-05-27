from .GlobalData import global_data
from .Apps import all_apps, App
from .Projects import all_projects
from .Projects import Projects
from .Pods import all_pods
from .Monitor import monitor
from .utils.oc import oc
import random
import logging
import os
import time
from concurrent.futures import ThreadPoolExecutor


class Task:
    def __init__(self, task):
        self.task = task
        self.templates = global_data.config["appTemplates"]
        self.logger = logging.getLogger('reliability')
        self.cwd = os.getcwd()
        random.seed()

    def get_targets(self, candidates, percent):
        targets = []
        if percent == 100:
            targets = candidates
        elif percent > 0:
            num_to_select = round(len(candidates) * (percent/100.0))
            if num_to_select > 0:
                targets = random.sample(candidates, num_to_select)
        return targets
    
    def get_percent(self):
        percent = 100
        if "applyPercent" in self.task:
            percent = int(self.task["applyPercent"])
        return percent
    
    def execute(self):
        all_apps.init()
        all_projects.init()
  #      all_projects = Projects()
  #      all_projects.projects = 2
  #      all_projects.max_projects = 9
  #      all_projects.projects = {'cakephp-mysql-example-0': {"app": None, "name": 'cakephp-mysql-example-0'}, 'nodejs-mongodb-example-1':{"app": None, "name": 'nodejs-mongodb-example-1'}} 
        all_pods.init()
        monitor.init()
        resource = self.task["resource"]
        action = self.task["action"]
        persona = self.task.setdefault("persona","admin")
        concurrency = self.task.setdefault("concurrency",1)

        # prepare concurrency number of kubeconfigs
        kubeconfigs = []

        if persona == "admin":
                kubeconfigs.append(global_data.kubeconfigs["kubeadmin"])
        elif persona == "developer":
            for i in range(0, concurrency):
                name = "testuser-" + str(i)
                kubeconfigs.append(global_data.kubeconfigs[name])

        # Project actions
        if resource == "projects":
            if action == "create":
                self.logger.debug("create projects")
                quantity = self.task["quantity"]
                for i in range(0, quantity):
                    project_base_name = random.choice(self.templates)["template"]
                    new_project = all_projects.add(project_base_name)
                    if new_project != None:
                        if new_project.name.startswith("eap"):
                            app = App("eap-app", new_project.name, project_base_name, "eap-app")
                        else:
                            app = App(project_base_name, new_project.name, project_base_name, project_base_name)
                        new_project.app = app
                        all_apps.add(app) 
                    # with ThreadPoolExecutor() as pool:
                    #     results = pool.map(all_projects.add, kubeconfigs)
                    #     for result in results:
                    #         print(result)          
            elif action == "delete":
                self.logger.debug("delete projects")
                projects = list(all_projects.projects.keys())
                projects_to_delete = self.get_targets(projects,self.get_percent())
                for project_to_delete in projects_to_delete:
                    all_projects.delete(project_to_delete)
            elif action == "check":
                self.logger.debug("check projects")
                all_projects.check_projects()
            elif action == "modify":
                projects = list(all_projects.projects.keys())
                projects_to_modify = self.get_targets(projects, self.get_percent())
                for project_to_modify in projects_to_modify:
                    all_projects.projects[project_to_modify].modify()

        # Application actions
        elif resource == "apps":
            if action == "build":
                self.logger.debug("Build apps")
                if len(all_apps.apps) > 0:
                    apps = list(all_apps.apps.keys())
                    apps_to_build = self.get_targets(apps, self.get_percent())
                    for app_to_build in apps_to_build:
                        all_apps.apps[app_to_build].build()
            elif action == "scaleUp":
                self.logger.debug("ScaleUp apps")
                apps = list(all_apps.apps.keys())
                apps_to_scale = self.get_targets(apps, self.get_percent())
                for app_to_scale in apps_to_scale:
                    all_apps.apps[app_to_scale].scale_up()
            elif action =="scaleDown":
                self.logger.debug("ScaleDown apps")
                apps = list(all_apps.apps.keys())
                apps_to_scale = self.get_targets(apps, self.get_percent())
                for app_to_scale in apps_to_scale:
                    all_apps.apps[app_to_scale].scale_down()
                #time.sleep(30)
            elif action == "visit":
                self.logger.debug("Visit Apps")
                apps = list(all_apps.apps.keys())
                apps_to_scale = self.get_targets(apps, self.get_percent())
                for app_to_scale in apps_to_scale:
                    all_apps.apps[app_to_scale].visit()
        elif resource == "pods":
            if action == "check":
                self.logger.debug("Check pods")
                all_pods.check()

        # Session actions
        elif resource == "session" :
            if action == "login":
                for i in range (0, concurrency):
                    if persona == "admin":
                        name = "kubeadmin"
                    elif persona == "developer":
                        name = "testuser-" + str(i)
                    password = global_data.users[name].password
                    kubeconfig = global_data.kubeconfigs[name]
                    result, rc = oc("login -u " + name + " -p " + password + " --kubeconfig " + kubeconfig)
                    if rc !=0 :
                        self.logger.error("Login failed")
        elif resource == "monitor" :
            if action == "clusteroperators":
                self.logger.debug("Monitor clusteroperators")
                monitor.check_operators()