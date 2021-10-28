from .GlobalData import global_data
from .Projects import all_projects
from .Apps import all_apps
from .Pods import all_pods
from .Task import Task
from .Session import Session
from .CustomizedTask import customizedTask
from .CerberusIntegration import cerberusIntegration
from .utils.SlackIntegration import slackIntegration
from concurrent.futures import ThreadPoolExecutor
import logging
import os
import time
import datetime
import sys


class TaskManager:
    def __init__(self, cerberus_history_file):
        self.logger = logging.getLogger('reliability')
        self.time_subs = {}
        self.time_subs["minute"] = 60
        self.time_subs["hour"] = 3600
        self.time_subs["day"] = 86400
        self.time_subs["week"] = 604800
        self.time_subs["month"] = 2419200
        self.init_timing()
        self.cwd = os.getcwd()
        self.cerberus_history_file = cerberus_history_file

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
            slackIntegration.post_message_in_slack("Reliability test is going to halt.")
            state = "halt"
            self.logger.info("Halt file found, shutting down reliability.")
        elif os.path.isfile(self.cwd + "/pause"):
            state = "pause"
            self.logger.info("Pause file found - pausing.")
        else:
            state = "run"
            if global_data.cerberus_enable:
                cerberus_status = cerberusIntegration.get_status(global_data.cerberus_api)
                if cerberus_status == "False":
                    if global_data.cerberus_fail_action == "halt":
                        state = "halt" 
                        self.logger.warning("Cerberus status is 'False'. Halt reliability test.")
                    elif global_data.cerberus_fail_action == "pause":
                        state = "pause" 
                        self.logger.warning("Cerberus status is 'False'. Pause reliability test. Resolve cerberus failure to continue.")
                    elif global_data.cerberus_fail_action == "continue":
                        self.logger.warning("Cerberus status is 'False'. Reliability test will continue.")
                    else:
                        self.logger.warning(f"Cerberus status is False. cerberus_fail_action '{global_data.cerberus_fail_action}' is not recognized. Reliability test will continue.")
                elif cerberus_status == "True":
                    self.logger.info("Cerberus status is 'True'.")
                else:
                    self.logger.warning(f"Getting Cerberus status failed, response is '{cerberus_status}'.")
                    
                cerberusIntegration.save_history(global_data.cerberus_api, self.cerberus_history_file)
            
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
        status = []
        status.append(f"Total projects: {str(all_projects.total_projects)}")
        status.append(f"Failed apps: {str(all_apps.failed_apps)}")
        status.append(f"Successful app visits: {str(global_data.app_visit_succeeded)}")
        status.append(f"Failed app visits: {str(global_data.app_visit_failed)}")
        status.append(f"Total builds: {str(global_data.total_build_count)}")
        status.append(f"Successful customized task: {str(customizedTask.customized_task_succeeded)}")
        status.append(f"Failed customized task: {str(customizedTask.customized_task_failed)}")
        status = "\n".join(status)
        self.logger.info("Reliability test status:\n"+ status)
        slackIntegration.post_message_in_slack("Reliability test status:\n" + status)

    def start(self):
        self.logger.info("Task manager started in working directory: " + self.cwd + " at: " + str(datetime.datetime.now()))
        self.next_execution_time = {}
        self.init_tasks()
        (next_execution, next_execution_time) = self.calculate_next_execution()
        current_time = 0

        all_pods.init()
        all_apps.init()
        all_projects.init()
        max_projects = global_data.maxProjects
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
        last_state = "run"
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
                last_state = "run"
            # only dump state on the first pause state after run state
            if state == "pause" and last_state != "pause":
                last_state = "pause"
                self.dump_stats()
            self.logger.info(f"Sleep '{global_data.sleepTime}' seconds before running next task type (minute/hour/day/week/month).")          
            time.sleep(global_data.sleepTime)
            current_time += global_data.sleepTime
        
        self.dump_stats()
        
