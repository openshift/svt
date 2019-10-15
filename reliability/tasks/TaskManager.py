from ReliabilityConfig import ReliabilityConfig
from .Projects import all_projects
from .Apps import all_apps
from .Pods import all_pods
from .Users import all_users
from .Task import Task
from .utils.oc import oc
import logging
import os
import time
import datetime
import sys


class TaskManager:
    def __init__(self,config_file):
        self.elapsed_time = 0
        self.time_subs = {}
        self.time_subs["minute"] = 60
        self.time_subs["hour"] = 3600
        self.time_subs["day"] = 86400
        self.time_subs["week"] = 604800
        self.time_subs["month"] = 2419200
        self.rc = ReliabilityConfig(config_file)
        self.rc.load_config()
        self.config = self.rc.config['reliability']
        self.init_timing()
        self.logger = logging.getLogger('reliability')
        self.cwd = os.getcwd()



    

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
        time_subs = self.config['timeSubstitutions']
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

        task = Task(self.config,{'action': 'create', 'resource': 'projects','quantity': 2})
        task.execute()
 #       task = Task(self.config,{'action': 'scaleUp', 'resource': 'apps'})
 #       task.execute()
 #       task = Task(self.config,{'action': 'scaleDown', 'resource': 'apps'})
 #       task.execute()
 #       task = Task(self.config,{'action': 'visit', 'resource': 'apps'})
 #       task.execute()
        task = Task(self.config,{'action': 'delete', 'resource': 'projects'})
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

    def dump_stats(self):
        all_apps.refresh_stats()
        self.logger.info("Total projects: " + str(all_projects.total_projects))
        self.logger.info("Failed apps " + str(all_apps.failed_apps))
        self.logger.info("Successful app visits: " + str(all_apps.visit_succeded))
        self.logger.info("Failed app visits: " + str(all_apps.visit_failed))
        self.logger.info("Total builds: " + str(all_apps.build_count))

    def start(self):
        self.logger.info("Task manager started in working directory: " + self.cwd + " at: " + str(datetime.datetime.now()))
        self.next_execution_time = {}
        self.init_tasks()
        (next_execution, next_execution_time) = self.calculate_next_execution()
        current_time = 0
        sleep_time = self.config["limits"]["sleepTime"]

        all_pods.init()
        all_apps.init()
        all_projects.init()
        all_projects.max_projects = int(self.config["limits"]["maxProjects"])

        state = "run"
        while state == "run" or state == "pause":
            self.rc.load_config()
            self.config = self.rc.config['reliability']
            self.logger.debug("Current time: " + str(current_time) + " next execution: " + str(next_execution))
            state = self.check_desired_state()
            if current_time >= next_execution_time and state == "run" : 
                for execution_type in next_execution.keys():
                    if execution_type in self.config["tasks"]:
                        tasks = self.config["tasks"][execution_type]
                        for task_to_execute in tasks:
                            task = Task(self.config,task_to_execute)
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
    rc = ReliabilityConfig("/home/mifiedle/mffiedler_git/svt/reliability/nextgen/config/simple_reliability.yaml")
    rc.load_config()
    config = rc.config['reliability']
    tm = TaskManager(config)
    tm.start()