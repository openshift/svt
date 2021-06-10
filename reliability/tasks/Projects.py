from .GlobalData import global_data
from .utils.oc import oc
from .utils.utils import random_string
from .Apps import App, all_apps
import logging
import random


class Project:
    def __init__(self, name, user):
        self.name = name
        self.user = user
        self.app = None
        self.logger = logging.getLogger('reliability')

    def modify(self, kubeconfig):
        key = random_string(8)
        value = random_string(256)
        (result, rc) = oc("create secret generic -n " + self.name + " " + key + " --from-literal=" + key + "=" + value, kubeconfig)
        if rc !=0 :
            self.logger.error("modify project: Secret creation failed")
            return "Project modify failed : " + self.name
        else :
            return "Project modify succeeded : " + self.name

class Projects:
    def __init__(self):
        self.projects = {}
        self.next_ids = {}
        self.max_projects = 10
        self.current_projects = 0
        self.total_projects = 0
        self.logger = logging.getLogger('reliability')

    def add(self, user, kubeconfig):    
        # use project_id_lock to protect shared mutable counter next_ids
        with global_data.project_id_lock:
            if user not in self.next_ids:
                self.next_ids[user] = 1
            else:
                self.next_ids[user] += 1
        name = user + "-" + str(self.next_ids[user])
        self.logger.debug("current projects: "+ str(self.current_projects))
        self.logger.debug("max projects: "+ str(self.max_projects))
        if self.current_projects >= self.max_projects:
            self.logger.warning("create_project: project " + name + " aborted. " + str(self.max_projects) + " projects already exist.")
            return None
        if name in self.projects:
            self.logger.error("create_project: project " + name + " already exists.")
            return None

        new_project = Project(name, user)
        (result, rc) = oc("new-project --skip-config-write " + name, kubeconfig)

        if rc == 0:
            self.projects[name] = new_project
            # developer is forbidden to patch resource "namespaces"
            kubeconfig_admin = global_data.kubeconfigs["kubeadmin"]
            oc("label namespace " + name + " purpose=reliability", kubeconfig_admin)
            # use projects_lock to protect shared mutable counters current_projects and total_projects
            with global_data.projects_lock:
                self.current_projects += 1
                self.total_projects += 1
            self.logger.debug("total projects: "+ str(self.total_projects))
        # in case project already exists before test start
        else:
            return None

        return new_project

    def delete(self, name, kubeconfig):
        if not (name in self.projects): 
            self.logger.error("delete_project: project " + name + " does not exist" )
        oc("delete project --wait=false " + name, kubeconfig)
        all_apps.init()
        app_to_remove = self.projects[name].app        
        all_apps.remove(app_to_remove)

        with global_data.projects_lock:
            self.current_projects -= 1

        # remove project from projects even if fails - suspect and should not be used
        self.projects.pop(name)

        return "Project deleted : " + name

    def check_projects(self, kubeconfig):
        oc("get projects -o wide -l purpose=reliability", kubeconfig)

    def get_project(self, name) :
        project = None
        if not name in self.projects:
            self.logger.warning("get project: project not in list: " + name)
        else:
            project = self.projects[name]
        return project

    def reconcile(self, kubeconfig):
        (result,rc) = oc("get projects -l purpose=reliability --no-headers | cut -f1 -d\" \"", kubeconfig)
        if rc == 0:
            actual_project_list = result.split('\n')
            for this_project in actual_project_list:
                if this_project != "" and not this_project in self.projects:
                    self.logger.warning("reconcile_projects: " + this_project + " exists on the cluster, but is not in our list of projects")
            for this_project in self.projects.keys():
                if not this_project in actual_project_list:
                    self.logger.warning("reconcile_projects: ") + this_project + " exists locally, but is not on the cluster"


    def init(self):
        pass
        
all_projects = Projects()

if __name__ == "__main__":
    p = Project("t2")
    p.modify()
  