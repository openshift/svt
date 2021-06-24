from .GlobalData import global_data
from .Projects import all_projects
from .Apps import all_apps
from .Pods import all_pods
from .Task import Task
from .Session import Session
from .CustomizedTask import customizedTask
from .utils.oc import oc
from concurrent.futures import ThreadPoolExecutor
import logging
import os
import time
import datetime
import sys


class TaskManager:
    def __init__(self,config_file):
        self.time_subs = {}
        self.time_subs["minute"] = 60
        self.time_subs["hour"] = 3600
        self.time_subs["day"] = 86400
        self.time_subs["week"] = 604800
        self.time_subs["month"] = 2419200
        self.init_global_data(config_file)
        self.init_timing()
        self.logger = logging.getLogger('reliability')
        self.cwd = os.getcwd()

    def init_global_data(self,config_file):
        global_data.init()
        global_data.load_data(config_file)

    def init_timing(self):
        def parse_time(time_string):
            unit = time_string[-1:]
            value = int(time_string[:-1])
            if unit == "s" :
                value = value
            elif unit == "m":
                value = value * 60
            elif unit == "h":
                value = value * 3600
            return value

        time_subs = {}
        time_subs = global_data.config['timeSubstitutions']
        for unit in time_subs.keys():
            self.time_subs[unit] = parse_time(time_subs[unit])

    def init_tasks(self):
        self.next_execution_time["minute"] = self.time_subs["minute"]
        self.next_execution_time["hour"] = self.time_subs["hour"]
        self.next_execution_time["day"] = self.time_subs["day"]
        self.next_execution_time["week"] = self.time_subs["week"]
        self.next_execution_time["month"] = self.time_subs["month"]
        self.next_task = {}
        
    def calculate_next_execution(self):
        next_execution_time = sys.maxsize
        next_execution = {}
        for interval in self.next_execution_time.keys():
            if self.next_execution_time[interval] < next_execution_time:
                next_execution_time = self.next_execution_time[interval]
                next_execution = {}
                next_execution[interval] = next_execution_time

            elif self.next_execution_time[interval] == next_execution_time:
                next_execution[interval] = self.next_execution_time[interval]
        return (next_execution, next_execution_time)

    def schedule_next(self,execution_type):
        self.next_execution_time[execution_type] += self.time_subs[execution_type]

    def start_test(self):

        all_pods.init()
        all_apps.init()
        all_projects.init()

        task = Task(global_data.config,{'action': 'create', 'resource': 'projects','quantity': 2})
        task.execute()
 #       task = Task(global_data.config,{'action': 'scaleUp', 'resource': 'apps'})
 #       task.execute()
 #       task = Task(global_data.config,{'action': 'scaleDown', 'resource': 'apps'})
 #       task.execute()
 #       task = Task(global_data.config,{'action': 'visit', 'resource': 'apps'})
 #       task.execute()
        task = Task(global_data.config,{'action': 'delete', 'resource': 'projects'})
        task.execute()

    def check_desired_state(self):
        if os.path.isfile(self.cwd + "/halt"):
            state = "halt"
            self.logger.info("Halt file found, shutting down reliability.")
        elif os.path.isfile(self.cwd + "/pause"):
            state = "pause"
            self.logger.info("Pause file found - pausing.")
        else:
            state = "run"
        
        return state
    
    # re-login all users to avoid login session token in kubeconfig expiration. The default timeout is 1 day.
    def relogin(self):
        # re-login 23 hours since last login
        if time.time() - global_data.last_login_time > 3600*23:
            self.logger.info("Re-login for all users to avoid login session token expiration")
            login_args = []
            for user in global_data.users:
                password = global_data.users[user].password
                kubeconfig = global_data.kubeconfigs[user]
                login_args.append((user, password, kubeconfig))
            # login concurrently
            with ThreadPoolExecutor(max_workers=51) as executor:
                results = executor.map(lambda t: Session().login(*t), login_args)
                for result in results:
                    self.logger.info(result)
            global_data.last_login_time = time.time()

    def dump_stats(self):
        self.logger.info("Total projects: " + str(all_projects.total_projects))
        self.logger.info("Failed apps " + str(all_apps.failed_apps))
        self.logger.info("Successful app visits: " + str(global_data.app_visit_succeeded))
        self.logger.info("Failed app visits: " + str(global_data.app_visit_failed))
        self.logger.info("Total builds: " + str(global_data.total_build_count))
        self.logger.info("Successful customized task: " + str(customizedTask.customized_task_succeeded))
        self.logger.info("Failed customized task: " + str(customizedTask.customized_task_failed))
    def start(self):
        self.logger.info("Task manager started in working directory: " + self.cwd + " at: " + str(datetime.datetime.now()))
        self.next_execution_time = {}
        self.init_tasks()
        (next_execution, next_execution_time) = self.calculate_next_execution()
        current_time = 0
        sleep_time = global_data.config["limits"]["sleepTime"]

        all_pods.init()
        all_apps.init()
        all_projects.init()
        max_projects = int(global_data.config["limits"]["maxProjects"])
        # get the projects creation concurrency
        projects_create_concurrency = 0
        try:
            for tasks in global_data.config["tasks"].values():
                for task in tasks:
                    if task["action"] == "create" and task["resource"] == "projects":
                        projects_create_concurrency = (task["concurrency"] if (task["concurrency"] > projects_create_concurrency) else projects_create_concurrency)
        except KeyError as e :
            self.logger.warning("KeyError " + str(e))
        if projects_create_concurrency != 0:
            if max_projects < projects_create_concurrency:
                self.logger.warning(f"maxProjects {max_projects} should be larger than the projects create concurrency {projects_create_concurrency}")
            # as projects are created concurrently, the next round will not start if the left capacity is less than the concurrency 
            all_projects.max_projects = max_projects-max_projects%projects_create_concurrency
            self.logger.info(str(all_projects.max_projects) + " is set as the max projects number regarding to the concurrency " 
                + str(projects_create_concurrency) + ". Origin maxProjects is " + str(max_projects))

        state = "run"
        while state == "run" or state == "pause":
            self.logger.debug("Current time: " + str(current_time) + " next execution: " + str(next_execution))
            state = self.check_desired_state()
            if current_time >= next_execution_time and state == "run" : 
                for execution_type in next_execution.keys():
                    if execution_type in global_data.config["tasks"]:
                        tasks = global_data.config["tasks"][execution_type]
                        for task_to_execute in tasks:
                            self.relogin()
                            task = Task(task_to_execute)
                            task.execute()
                    self.schedule_next(execution_type)
                (next_execution, next_execution_time) = self.calculate_next_execution()
            if state == "pause":
                self.dump_stats()                
            time.sleep(sleep_time)
            current_time += sleep_time
        
        self.dump_stats()
            

if __name__ == "__main__":
    
    sys.path.append("..")
    rc = ReliabilityConfig("<path to config file, example: ../config/simple_reliability.yaml>")
    rc.load_config()
    config = rc.config['reliability']
    tm = TaskManager(config)
    tm.start()
