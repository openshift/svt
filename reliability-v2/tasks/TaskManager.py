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
        label = f"[User: {user}] [Task: {task}]"
        rc = 0
        self.logger.info(f"{label}: will be run")
        if task.startswith('oc ',0,3):
            task_split = task.split("oc ")
            cmd = task_split[1]
            _, rc = self.tasks.oc_task(cmd, user)
        elif task.startswith('kubectl ',0,8):
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
            _, rc = self.tasks.shell_task(task, user)
        self.logger.info((f"'{label}: finished. Result is: '{rc}'."))

        return rc

    def run_tasks(self,users_task):
        #new_loop = asyncio.new_event_loop()
        #asyncio.set_event_loop(new_loop)

        group_name = users_task.get("group_name","")
        user =  users_task.get("user","os")
        loops = users_task["loops"]
        trigger = users_task["trigger"]
        interval = users_task["interval"]
        jitter = users_task["jitter"]
        pre_tasks = users_task["pre_tasks"]
        tasks = users_task["tasks"]
        post_tasks = users_task["post_tasks"]
        label = f"[Group:{group_name}] [User: {user}] [Total Loops: {loops}]"

        if jitter > 0:
            random_jitter = random.randint(1,jitter)
            self.logger.info(f"{label}: will sleep {random_jitter} seconds as jitter before loop")
            time.sleep(random_jitter)

        state = self.check_state()
        # run pre tasks
        while state == "pause":
            time.sleep(60)
            state = self.check_state()
        pre_rc = 0
        if state == "run":
            self.logger.info(f"{label}: will run pre_tasks")
            for pre_task in pre_tasks:
                if pre_rc == 0:
                    pre_rc = self.run_task(pre_task, user)
                    time.sleep(20)
        if pre_rc != 0:
            result = f"{label}: pre tasks failed." 
        else:
            state = self.check_state()
            if loops == "forever":
                loop = 0
                while state != "halt":
                    if state == "run":
                        self.logger.info(f"{label}: will run loop {loop}")
                        rc = 0
                        for task in tasks:
                            if rc == 0:
                                rc = self.run_task(task, user)
                                # sleep interval seconds between tasks
                                self.logger.info(f"{label}: will sleep {interval}s before next task")
                                time.sleep(interval)           
                        loop += 1
                        self.logger.info(f"{label}: will sleep {trigger}s after loop '{loop}'")
                        time.sleep(trigger)
                        state = self.check_state()
                    elif state == "pause":
                        time.sleep(60)
                        state = self.check_state()
                slackIntegration.info(f"{label}: is going to halt after loop '{loop}'")
                result = f"{label}: halted after loop '{loop}'"

            elif isinstance(loops,int) and loops > 0:
                for loop in range(loops):
                    if state == "halt":
                        slackIntegration.info(f"{label}: is going to halt before loop '{loop}'")
                        result = f"{label}: halted before loop '{loop}'"
                        break
                    while state == "pause":
                        time.sleep(60)
                        state = self.check_state()
                    if state == "run":
                        self.logger.info(f"{label}: will run loop {loop}")
                        rc = 0
                        for task in tasks:
                            if rc == 0:
                                rc = self.run_task(task, user)
                                self.logger.info(f"{label}: will sleep {interval}s before next task")
                                time.sleep(interval)           
                        self.logger.info(f"{label}: will sleep {trigger}s after loop '{loop}'")
                        time.sleep(trigger)
                        state = self.check_state()
                    elif state == "halt":
                        slackIntegration.info(f"{label}: is going to halt after loop '{loop}'")
                        result = f"{label}: halted after loop '{loop}'"
                        break
                result = f"{label}: loop finished"
            else:
                self.logger.error(f"Invalid loop '{loops}'.")
            
            # run post tasks even when there is halt
            state = self.check_state()
            while state == "pause":
                time.sleep(60)
                state = self.check_state()
            self.logger.info(f"{label}: will run post_tasks")

            post_rc = 0
            for post_task in post_tasks:
                if post_rc == 0:
                    post_rc = self.run_task(post_task, user)
                    time.sleep(20)
        return result

    def run_users_tasks(self,group):
        name = group.get("name","")
        user_name = group.get("user_name","")
        user_start = group.get("user_start",None)
        user_end = group.get("user_end",None)
        loops = group.get("loops",1)
        trigger = group.get("trigger",0)
        jitter = group.get("jitter",0)
        pre_tasks = group.get("pre_tasks",[])
        tasks = group.get("tasks",[])
        post_tasks = group.get("post_tasks",[])
        interval = group.get("interval",60)
        users_tasks = []
        user_count = 0
        if user_start == None and user_end == None: 
            users_tasks.append({"user":user_name,"group_name":name,"loops":loops,"trigger":trigger,"interval":interval,"jitter":jitter,"pre_tasks":pre_tasks,"tasks":tasks,"post_tasks":post_tasks})
            user_count = 1
        elif user_end > user_start:
            for i in range(user_start, user_end):
                users_tasks.append({"user":f"{user_name}{i}","group_name":name,"loops":loops,"trigger":trigger,"interval":interval,"jitter":jitter,"pre_tasks":pre_tasks,"tasks":tasks,"post_tasks":post_tasks})
            user_count = user_end - user_start
        if user_count > 0:
            self.logger.info(f"Will run group '{name}' with {user_count} users.")
            slackIntegration.info(f"Group {name} will run tasks with {user_count} users for {loops} loops. Adding a jitter of {jitter}s before group test started, wait {trigger}s between loops, wait {interval}s between tasks.")
            # run tasks with concurrent users
            with ThreadPoolExecutor(max_workers=user_count) as executor:
                results = executor.map(self.run_tasks, users_tasks)
                for result in results:
                    self.logger.info(f"User in group '{name} finished its run'. Result is {result}")
            return (f"Finished running group '{name}'.")
        else:
            return (f"Can not run group '{name}'. user_end should be larger than user_end.")

    def run_groups(self,groups):
        with ThreadPoolExecutor() as executor:
            results = executor.map(self.run_users_tasks,groups)
            for result in results:
                self.logger.info(result)

    def check_state(self):
        if os.path.isfile(os.getcwd() + "/halt"):
            #slackIntegration.info("Reliability test is going to halt.")
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
        slackIntegration.info("Reliability test results:\n" + results)
