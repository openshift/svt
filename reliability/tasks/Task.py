from .GlobalData import global_data
from .Apps import all_apps, App
from .Projects import all_projects
from .Projects import Projects
from .Pods import all_pods
from .Monitor import monitor
from .Session import Session
from .utils.oc import oc
from .utils.LoadApp import LoadApp
import random
import logging
import time
from concurrent.futures import ThreadPoolExecutor
import asyncio

class Task:
    def __init__(self, task):
        self.task = task
        self.templates = global_data.config["appTemplates"]
        self.logger = logging.getLogger('reliability')
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

        # prepare concurrency number of users
        users = []
        # ThreadPoolExecutor workers
        workers = 0

        if persona == "admin":
                users.append("kubeadmin")
                workers = 1
        elif persona == "developer":
            for i in range(0, concurrency):
                users.append("testuser-" + str(i))
                workers += 1

        # Project actions
        if resource == "projects":
            if action == "create":
                self.logger.debug("create projects")
                quantity = self.task["quantity"]
                template = random.choice(global_data.config["appTemplates"])["template"]
                for i in range(0, quantity):
                    projects = []
                    # prepare parameters list - user and kubeconfig - for all_projects.add
                    project_create_args = []
                    for user in users:
                        kubeconfig = global_data.kubeconfigs[user]
                        project_create_args.append((user, kubeconfig))
                    # create project concurrently
                    with ThreadPoolExecutor(max_workers=workers) as executor:
                        results =  executor.map(lambda t: all_projects.add(*t), project_create_args)
                        for result in results:
                            if result != None:
                                projects.append(result)
                                self.logger.info(f"Project added is: {result.name}")
                    if len(projects) > 0:
                        # prepare parameters list - app name and kubeconfig - for all_apps.add
                        app_add_args = []
                        for project in projects:             
                            if template.startswith("eap"):
                                app = App("eap-app", project.name, template, "eap-app")
                            else:
                                app = App(template, project.name, template, template)
                            kubeconfig = global_data.kubeconfigs[project.user]
                            app_add_args.append((app, kubeconfig))
                        # add app for all projects created concurrently
                        with ThreadPoolExecutor(max_workers=workers) as executor:
                            results =  executor.map(lambda t: all_apps.add(*t), app_add_args)
                            for result in results:
                                if result != None:
                                    all_projects.projects[result.project].app = result
                                    self.logger.info(f"App added to project: {result.project}.")
                                
            elif action == "delete":
                self.logger.debug("delete projects")
                projects = list(all_projects.projects.keys())
                projects_to_delete = self.get_targets(projects,self.get_percent())
                # prepare parameters list - project name and kubeconfig - for all_projects.delete
                project_delete_args = []
                for project_to_delete in projects_to_delete:
                    user = all_projects.projects[project_to_delete].user
                    kubeconfig = global_data.kubeconfigs[user]
                    project_delete_args.append((project_to_delete,kubeconfig))
                # delete projects concurrently
                with ThreadPoolExecutor(max_workers=workers) as executor:
                    results = executor.map(lambda t: all_projects.delete(*t), project_delete_args)
                    for result in results:
                        self.logger.info(result)

            elif action == "check":
                self.logger.debug("check projects")
                # check projects concurrently
                kubeconfigs = []
                for user in users:
                    kubeconfigs.append(global_data.kubeconfigs[user])
                with ThreadPoolExecutor(max_workers=workers) as executor:
                    results =  executor.map(all_projects.check_projects, kubeconfigs)

            elif action == "modify":
                projects = list(all_projects.projects.keys())
                projects_to_modify = self.get_targets(projects, self.get_percent())
                # prepare parameters list - project name and kubeconfig - for project.modify
                project_modify_args = []
                for project_to_modify in projects_to_modify:
                    # to avoid the project being deleted -async after getting the list.
                    try: 
                        user = all_projects.projects[project_to_modify].user
                        kubeconfig = global_data.kubeconfigs[user]
                        project_modify_args.append((project_to_modify, kubeconfig))
                    except KeyError:
                        self.logger.info(f"Projet {project_to_modify} no longer exists in projects list.")
                # modify projects concurrently
                with ThreadPoolExecutor(max_workers=workers) as executor:
                    results = executor.map(lambda t: all_projects.projects[t[0]].modify(t[1]), project_modify_args)
                    for result in results:
                        self.logger.info(result)

        # Application actions
        elif resource == "apps":
            if action == "build":
                self.logger.debug("Build apps")
                if len(all_apps.apps) > 0:
                    apps = list(all_apps.apps.keys())
                    apps_to_build = self.get_targets(apps, self.get_percent())
                    # prepare parameters list - app name and kubeconfig - for app.build
                    app_build_args = []
                    for app_to_build in apps_to_build:
                        try:
                            project = all_apps.apps[app_to_build].project
                            user = all_projects.projects[project].user
                            kubeconfig = global_data.kubeconfigs[user]
                            app_build_args.append((app_to_build, kubeconfig))
                        except KeyError:
                            self.logger.info(f"Application {app_to_build} no longer exists in apps list.")
                    # add apps concurrently
                    with ThreadPoolExecutor(max_workers=workers) as executor:
                        results = executor.map(lambda t: all_apps.apps[t[0]].build(t[1]), app_build_args)
                        for result in results:
                            self.logger.info(result)

            elif action == "scaleUp":
                self.logger.debug("ScaleUp apps")
                if len(all_apps.apps) > 0:
                    apps = list(all_apps.apps.keys())
                    apps_to_scale = self.get_targets(apps, self.get_percent())
                    # prepare parameters list - app name and kubeconfig - for app.scale_up
                    app_scale_args = []
                    for app_to_scale in apps_to_scale:
                        try:
                            project = all_apps.apps[app_to_scale].project
                            user = all_projects.projects[project].user
                            kubeconfig = global_data.kubeconfigs[user]
                            app_scale_args.append((app_to_scale, kubeconfig))
                        except KeyError:
                            self.logger.info(f"Application {app_to_scale} no longer exists in apps list.")
                    # scale up apps concurrently
                    with ThreadPoolExecutor(max_workers=workers) as executor:
                        results = executor.map(lambda t: all_apps.apps[t[0]].scale_up(t[1]), app_scale_args)
                        for result in results:
                            self.logger.info(result)

            elif action =="scaleDown":
                self.logger.debug("ScaleDown apps")
                if len(all_apps.apps) > 0:
                    apps = list(all_apps.apps.keys())
                    apps_to_scale = self.get_targets(apps, self.get_percent())
                    # prepare parameters list - app name and kubeconfig - for app.scale_down
                    app_scale_args = []
                    for app_to_scale in apps_to_scale:
                        try:
                            project = all_apps.apps[app_to_scale].project
                            user = all_projects.projects[project].user
                            kubeconfig = global_data.kubeconfigs[user]
                            app_scale_args.append((app_to_scale, kubeconfig))
                        except KeyError:
                            self.logger.info(f"Application {app_to_scale} no longer exists in apps list.")
                    # add down apps concurrently
                    with ThreadPoolExecutor(max_workers=workers) as executor:
                        results = executor.map(lambda t: all_apps.apps[t[0]].scale_down(t[1]), app_scale_args)
                        for result in results:
                            self.logger.info(result)
                #time.sleep(30)

            # using coroutines for concurrent app visit
            elif action == "visit":
                self.logger.debug("Visit Apps")
                if len(all_apps.apps) > 0:
                    loadApp = LoadApp()
                    urls = []
                    apps = list(all_apps.apps.keys())
                    apps_to_visit = self.get_targets(apps, self.get_percent())
                    for app_to_visit in apps_to_visit:
                        urls.append("http://" + all_apps.apps[app_to_visit].route + "/")
                    loadApp.set_tasks(urls, concurrency)
                    loop = asyncio.get_event_loop()
                    loop.run_until_complete(asyncio.wait(loadApp.tasks))
                    global_data.app_visit_succeeded += loadApp.app_visit_succeeded
                    global_data.app_visit_failed += loadApp.app_visit_failed
                    self.logger.info(f"Succeeded visit: {str(loadApp.app_visit_succeeded)}. Failed visit: {str(loadApp.app_visit_failed)}")

        elif resource == "pods":
            if action == "check":
                self.logger.debug("Check pods")
                # prepare parameters list - project name and kubeconfig - for all_pods.check
                pod_check_args = []
                for user in users:
                    kubeconfig = global_data.kubeconfigs[user]
                    if user == "kubeadmin":
                        pod_check_args.append(("all-namespaces", kubeconfig))
                    else:
                        for project in all_projects.projects.values():
                            if project.user == user:
                                pod_check_args.append((project.name, kubeconfig))
                # check pods concurrently
                with ThreadPoolExecutor(max_workers=workers) as executor:
                    results = executor.map(lambda t: all_pods.check(*t), pod_check_args)

        # Session actions
        elif resource == "session" :
            if action == "login":
                login_args = []
                for user in users:
                    password = global_data.users[user].password
                    kubeconfig = global_data.kubeconfigs[user]
                    login_args.append((user, password, kubeconfig))
                # login concurrently
                with ThreadPoolExecutor(max_workers=workers) as executor:
                    results = executor.map(lambda t: Session().login(*t), login_args)
                    for result in results:
                        self.logger.info(result)

        elif resource == "monitor" :
            if action == "clusteroperators":
                self.logger.debug("Monitor clusteroperators")
                monitor.check_operators()