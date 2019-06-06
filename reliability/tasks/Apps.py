from  .utils.oc import oc
import requests
import time
import logging


class App:
    def __init__(self, deployment, project, template, build_config,route=""):
        self.project = project
        self.template = template
        self.deployment = deployment
        self.build_config = build_config
        self.route = route
        self.build_count = 0
        self.visit_succeded = 0
        self.visit_failed = 0
        self.logger = logging.getLogger('reliability')

    def build(self):
        (result, rc) = oc("start-build -n " + self.project + " " + self.build_config)
        if rc != 0:
            self.logger.error("build_app: Failed to create app " + self.deployment + " in project " + self.project)
        else:
            self.build_count += 1

    def visit(self):
        visit_success = False
        try:
            r = requests.get("http://" + self.route + "/")
            self.logger.info(str(r.status_code) + ": visit: " + self.route)
            if r.status_code == 200:
                self.visit_succeded += 1
                visit_success = True
            else:
                self.visit_failed += 1
        except Exception:
            self.visit_failed += 1
            self.logger.error("visit: " + self.route)
        return visit_success
        

    def scale_up(self):
        (result, rc) = oc("scale --replicas=2 -n " + self.project + " dc/" + self.deployment)
        if rc !=0 :
            self.logger.error("scale_up: Failed to scale up " + self.project + "." + self.deployment)
    
    def scale_down(self):
        (result, rc) = oc("scale --replicas=1 -n " + self.project + " dc/" + self.deployment)
        if rc !=0 :
            self.logger.error("scale_down: Failed to scale down " + self.project + "." + self.deployment)
        
    
class Apps:
    def __init__(self):
        self.build_count = 0
        self.visit_succeded = 0
        self.visit_failed = 0
        self.failed_apps = 0
        self.apps = {}
        self.logger = logging.getLogger('reliability')

    def add(self, app):
        (result, rc) = oc("new-app -n " + app.project + " --template " + app.template)
        if rc != 0:
            self.logger.error("create_app: Failed to create app " + app.deployment + " in project " + app.project)
        else:
            self.apps[app.project + "." + app.deployment] = app
            (route,rc) = oc("get route --no-headers -n " + app.project + " | awk {'print $2'} | grep " + app.template)
            if rc == 0:
                app.route = route.rstrip()
                max_tries = 60
                current_tries = 0
                visit_success = False
                while not visit_success and current_tries <= max_tries:
                    # don't count failed visits before app is ready
                    app.visit_failed = 0
                    self.logger.info(app.template + " route not available yet, sleeping 10 seconds") 
                    time.sleep(10)
                    current_tries += 1
                    visit_success = app.visit()
                if not visit_success:
                    self.failed_apps += 1
                    self.logger.error("add_app: " + app.project + "." + app.deployment + " did not become available" )

    def refresh_stats(self):
        for key in self.apps.keys():
            self.build_count += self.apps[key].build_count
            self.visit_succeded += self.apps[key].visit_succeded
            self.visit_failed += self.apps[key].visit_failed

    
    # removing an app just removes the dictionary entry, actual app removed by project deletion
    def remove(self,app):
        self.build_count += app.build_count
        self.visit_succeded += app.visit_succeded
        self.visit_failed += app.visit_failed
        self.apps.pop(app.project + "." + app.deployment)

    def simulate(self):
        apps = {}
        app1 = App('cakephp-mysql-example','cakephp-mysql-example-0','cakephp-mysql-example','cakephp-mysql-example')
        self.apps[app1.project + "." + app1.deployment] = app1
#        app2 = App('nodejs-mongodb-example','nodejs-mongodb-example-1','nodejs-mongodb-example','nodejs-mongodb-example')
#        self.apps[app2.project + "." + app2.deployment] = app2


    def init(self):
        pass

all_apps=Apps()   
    
if __name__ == "__main__":
    app = App("cakephp-mysql-example", "t1", "cakephp-mysql-example","cakephp-mysql-example")
    apps = Apps()
 #   apps.add(app)
 #   time.sleep(180)
    app.visit()
    app.scale_up()
    time.sleep(30)
    app.scale_down()
    app.build()