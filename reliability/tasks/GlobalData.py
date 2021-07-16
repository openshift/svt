from tasks.Users import all_users, User
from tasks.Contexts import all_contexts
from threading import Lock
import logging
import time
import os
import yaml

# a class to hold shared data, config, users, kubeconfigs
class GlobalData:

    def __init__(self):
        self.config = None

        self.users = {}
        self.kubeconfigs = {}

        self.project_id_lock = Lock()
        self.projects_lock = Lock()
        self.apps_lock = Lock()
        self.builds_lock = Lock()
        self.customized_task_lock = Lock()

        self.total_build_count = 0
        self.app_visit_succeeded = 0
        self.app_visit_failed = 0

        self.last_login_time = time.time()

        self.logger = logging.getLogger('reliability')
        
    def valid_config(self, config):
        try:
            self.config = config["reliability"]
            # validdate kubeconfig file
            kubeconfig = self.config["kubeconfig"]
            if os.path.isfile(kubeconfig):
                self.kubeconfig = kubeconfig
            else:
                self.logger.error(f"kubeconfig file '{kubeconfig}' does not exist.")
                return False
            # validdate user file
            user_file = self.config['users'][1]["user_file"]
            if os.path.isfile(user_file):
                    self.user_file = user_file
            else:
                self.logger.error(f"user_file '{user_file}' does not exist. Please check the config file.")
                return False
            # validate kubeadmin_password file
            kubeadmin_password_file = self.config['users'][0]["kubeadmin_password"]
            if os.path.isfile(kubeadmin_password_file):
                self.kubeadmin_password_file = kubeadmin_password_file
            else:
                self.logger.error(f"kubeadmin_password file '{kubeadmin_password_file}' does not exist. Please the your config file.")
                return False
            self.maxProjects = self.config["limits"].get("maxProjects", 25)
            self.sleepTime = self.config["limits"].get("sleepTime", 10)
            self.cerberus_enable = self.config["cerberusIntegration"].get("cerberus_enable", False)
            self.cerberus_api = self.config["cerberusIntegration"].get("cerberus_api", "http://0.0.0.0:8080")
            self.cerberus_fail_action = self.config["cerberusIntegration"].get("cerberus_fail_action", "continue")      
        except KeyError as e:
            self.logger.error(f"config file should contain key {e}.")
            return False
        return True
    
    def load_data(self, config_file):
        # load config
        if os.path.isfile(config_file):
            with open(config_file) as f:
                config = yaml.safe_load(f)
                if not self.valid_config(config):
                    return False
        else:
            self.logger.error(f"config file '{config_file}' does not exist.")
            return False
        
        all_users.init()
        # load all developer users
        all_users.load_users(self.user_file)       
        # load admin user
        all_users.load_admin(self.kubeadmin_password_file)

        self.users = all_users.get_users()
        
        # create kubeconfig with contexts for all users
        all_contexts.init()
        all_contexts.create_kubeconfigs(self.kubeconfig,self.users)
        self.last_login_time = time.time()
        self.kubeconfigs = all_contexts.kubeconfigs
        return True

# make it singleton
global_data = GlobalData()

if __name__ == "__main__":
    global_data.load_data('<path to config file>')
    print(global_data.config)
