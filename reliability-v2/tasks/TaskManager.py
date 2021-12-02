import logging
import time
import os
import random
from concurrent.futures import ThreadPoolExecutor
import asyncio
from tasks.GlobalData import global_data
from tasks.Tasks import Tasks
from integrations.SlackIntegration import slackIntegration
from integrations.CerberusIntegration import cerberusIntegration

class TaskManager:    
    def __init__(self, cerberus_history_file):
        # config logger
        self.logger = logging.getLogger('reliability')
        self.tasks = Tasks()
        self.cerberus_history_file = cerberus_history_file

    def run_task(self,task,user):
        rc = 0
        self.logger.info(f"User '{user}' will run task '{task}'")
        if task.startswith('oc ',0,3):
            task_split = task.split("oc ")
            cmd = task_split[1]
            _, rc = self.tasks.oc_task(cmd, user)
        elif task.startswith('kubectl ',0,8):
            # todo: change name of oc.py
            task_split = task.split("kubectl ")
            cmd = task_split[1]
            _, rc = self.tasks.kubectl_task(cmd, user)
        elif task.startswith('func ',0,5):
            task_split = task.split(" ")
            func = task_split[1]
            if len(task_split) > 2:
                rc = 0
                for i in range(int(task_split[2])):
                    if rc == 0:
                        namespace = f"{user}-{i}"
                        if len(task_split) == 3:
                            _, rc = eval(f"self.tasks.{func}")(user,namespace)
                        elif len(task_split) == 4:
                            _, rc = eval(f"self.tasks.{func}")(user,namespace,task_split[3])
                    else:
                        break
            else:
                _, rc = eval(f"self.tasks.{func}")(user)
        else:
            _, rc = self.tasks.shell_task(task)
        self.logger.info((f"'User {user}' finished running '{task}' and return '{rc}'."))

        return rc

    def run_tasks(self,users_task):
        #new_loop = asyncio.new_event_loop()
        #asyncio.set_event_loop(new_loop)

        name = users_task.get("name","")
        user =  users_task.get("user","os")
        loops = users_task["loops"]
        trigger = users_task["trigger"]
        interval = users_task["interval"]
        jitter = users_task["jitter"]
        tasks = users_task["tasks"]

        random_jitter = random.randint(1,jitter)
        self.logger.info(f"User {user} will sleep {random_jitter} seconds as jitter")
        time.sleep(random_jitter)

        state = self.check_state()

        if loops == "forever":
            loop = 0
            while state != "halt":
                if state == "run":
                    self.logger.info(f"User '{user}' will run loop {loop}")
                    rc = 0
                    for task in tasks:
                        if rc == 0:
                            rc = self.run_task(task, user)
                            # sleep interval seconds between tasks
                            self.logger.info(f"Will sleep {interval} before next task for user '{user}'")
                            time.sleep(interval)           
                    loop += 1
                    self.logger.info(f"Will sleep {trigger} before next loop of group '{name}'")
                    time.sleep(trigger)
                    state = self.check_state()
                elif state == "pause":
                    time.sleep(60)
                    state = self.check_state()
            slackIntegration.post_message_in_slack(f"Reliability test is going to halt")
            rc = 1

        elif isinstance(loops,int) and loops > 0:
            for loop in range(loops):
                if state == "halt":
                    slackIntegration.post_message_in_slack(f"Reliability test is going to halt")
                    rc = 1
                    break
                while state == "pause":
                    time.sleep(60)
                    state = self.check_state()
                if state == "run":
                    self.logger.info(f"User '{user}' will run loop {loop}")
                    rc = 0
                    for task in tasks:
                        if rc == 0:
                            rc = self.run_task(task, user)
                            self.logger.info(f"Will sleep {interval} before next task for user '{user}'")
                            time.sleep(interval)
                            state = self.check_state()
                    self.logger.info(f"Will sleep {trigger} before next loop of group '{name}'")
                    time.sleep(trigger)
                elif state == "halt":
                    slackIntegration.post_message_in_slack(f"Reliability test is going to halt")
                    rc = 1
                    break
        else:
            self.logger.error(f"Invalid loop '{loops}'.")

        return rc

    def run_users_tasks(self,group):
        name = group.get("name","")
        persona = group.get("persona","os")
        users = group.get("users",1)
        loops = group.get("loops",1)
        trigger = group.get("trigger",0)
        jitter = group.get("jitter",0)
        tasks = group.get("tasks",[])
        interval = group.get("interval",60)
        users_tasks = []
        # todo: validate
        if persona == "admin":
            users_tasks.append({"user":"kubeadmin","name":name,"loops":loops,"trigger":trigger,"interval":interval,"jitter":jitter,"tasks":tasks})
        elif persona == "developer":
            for i in range(users):
                users_tasks.append({"user":f"testuser-{i}","name":name,"loops":loops,"trigger":trigger,"interval":interval,"jitter":jitter,"tasks":tasks})

        self.logger.info(f"Will run group '{name}' with {users} users concurrently")
        # run tasks with concurrent users
        with ThreadPoolExecutor() as executor:
            results = executor.map(self.run_tasks, users_tasks)
            for result in results:
                self.logger.info(f"Finished running group '{name}' result is {result}")
        return (f"Finished running group: {group}")

    def run_groups(self,groups):
        with ThreadPoolExecutor() as executor:
            results = executor.map(self.run_users_tasks,groups)
            for result in results:
                self.logger.info(result)

    def check_state(self):
        if os.path.isfile(os.getcwd() + "/halt"):
            slackIntegration.post_message_in_slack("Reliability test is going to halt.")
            state = "halt"
            self.logger.info("Halt file found, shutting down reliability.")
        elif os.path.isfile(os.getcwd() + "/pause"):
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

    def start(self):
        # run groups concurrently
        groups = global_data.config["groups"]
        self.logger.info(f"Will run the following groups concurrently {groups}")
        self.run_groups(groups)

        # get results
        results = self.tasks.get_results()
        slackIntegration.post_message_in_slack("Reliability test results:\n" + results)
