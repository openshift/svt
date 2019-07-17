from .utils.oc import oc
from .utils.utils import random_string
from .Apps import App, all_apps
import logging


class Project:
    def __init__(self, name):
        self.name = name
        self.app = None
        self.logger = logging.getLogger('reliability')

    def modify(self):
        key = random_string(8)
        value = random_string(256)
        (result, rc) = oc("create secret generic -n " + self.name + " " + key + " --from-literal=" + key + "=" + value)
        if rc !=0 :
            self.logger.error("modify project: Secret creation failed")




class Projects:
    def __init__(self):
        self.projects = {}
        self.next_id = 0
        self.max_projects = 10
        self.current_projects = 0
        self.total_projects = 0
        self.logger = logging.getLogger('reliability')

    def add(self, name):
        name = name + "-" + str(self.next_id)

        if self.current_projects == self.max_projects:
            self.logger.warning("create_project: project " + name + ". " + str(self.max_projects) + " already exist.")
            return None
        if name in self.projects:
            self.logger.error("create_project: project " + name + " already exists.")
            return None

        new_project = Project(name)
        (result, rc) = oc("new-project --skip-config-write " + name)
        self.next_id += 1
        self.current_projects += 1
        self.total_projects += 1

        if rc == 0:
            self.projects[name] = new_project
            oc("label namespace " + name + " purpose=reliability")

        return new_project

    def delete(self, name):
        if not (name in self.projects): 
            self.logger.error("delete_project: project " + name + " does not exist" )
        oc("delete project --wait=false " + name)
        all_apps.init()
        app_to_remove = self.projects[name].app        
        all_apps.remove(app_to_remove)

        self.current_projects -= 1

        # remove project from projects even if fails - suspect and should not be used
        self.projects.pop(name)

    def check_projects(self):
        oc("get projects -o wide -l purpose=reliability")


    def get_project(self, name) :
        project = None
        if not name in self.projects:
            self.logger.warning("get project: project not in list: " + name)
        else:
            project = self.projects[name]
        return project

   
    def reconcile(self):
        (result,rc) = oc("get projects -l purpose=reliability --no-headers | cut -f1 -d\" \"")
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
  