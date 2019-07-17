from .Apps import all_apps, App
from .Projects import all_projects
from .Projects import Projects
from .Pods import all_pods
from .utils.oc import oc
import random
import logging
import time


class Task:
    def __init__(self,config,task):
        self.config = config
        self.task = task
        self.templates = config["appTemplates"]
        self.logger = logging.getLogger('reliability')
        random.seed()



    
    def execute(self):
        all_apps.init()
        all_projects.init()
  #      all_projects = Projects()
  #      all_projects.projects = 2
  #      all_projects.max_projects = 9
  #      all_projects.projects = {'cakephp-mysql-example-0': {"app": None, "name": 'cakephp-mysql-example-0'}, 'nodejs-mongodb-example-1':{"app": None, "name": 'nodejs-mongodb-example-1'}} 
        all_pods.init()
        resource = self.task["resource"]
        action = self.task["action"]

        if resource == "projects":
            if action == "create":
                self.logger.debug("create projects")
                quantity = self.task["quantity"]
                for i in range(0, quantity):
                    project_base_name = random.choice(self.templates)["template"]
                    new_project = all_projects.add(project_base_name)
                    if new_project != None:
                        app = App(project_base_name, new_project.name, project_base_name, project_base_name)
                        new_project.app = app
                        all_apps.add(app)            
            elif action == "delete":
                self.logger.debug("delete projects")
                projects = list(all_projects.projects.keys())
                project_to_delete = random.choice(projects)
                all_projects.delete(project_to_delete)
            elif action == "check":
                self.logger.debug("check projects")
                all_projects.check_projects()
            elif action == "modify":
                for project_key in all_projects.projects.keys():
                    all_projects.projects[project_key].modify()
        elif resource == "apps":
            if action == "build":
                self.logger.debug("Build apps")
                if len(all_apps.apps) > 0:
                    apps = list(all_apps.apps.keys())
                    app_to_build_key = random.choice(apps)
                    app_to_build = all_apps.apps[app_to_build_key]
                    app_to_build.build()
            elif action == "scaleUp":
                self.logger.debug("ScaleUp apps")
                all_apps.init()
                for app_key in all_apps.apps.keys():
                    all_apps.apps[app_key].scale_up()
            elif action =="scaleDown":
                self.logger.debug("ScaleDown apps")
                for app_key in all_apps.apps.keys():
                    all_apps.apps[app_key].scale_down()
                time.sleep(30)
            elif action == "visit":
                self.logger.debug("Visit Apps")
                for app_key in all_apps.apps.keys():
                    all_apps.apps[app_key].visit()
        elif resource == "pods":
            if action == "check":
                self.logger.debug("Check pods")
                all_pods.check()
        elif resource == "session" :
            if action == "login":
                result, rc = oc("login -u " + self.task["user"] + " -p " + self.task["password"])
                if rc !=0 :
                    self.logger.error("Login failed")
