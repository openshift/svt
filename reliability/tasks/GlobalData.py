from ReliabilityConfig import ReliabilityConfig
from tasks.Users import all_users, User
from tasks.Contexts import all_contexts
from threading import Lock
import logging
import time

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
    
    def load_data(self, config_file):
        # load config
        rc = ReliabilityConfig(config_file)
        rc.load_config()
        self.config = rc.config['reliability']
        
        all_users.init()
        # load all developer users
        all_users.load_users(self.config['users'][1]["user_file"])
              
        # load admin user
        all_users.load_admin(self.config['users'][0]["kubeadmin_file"])

        self.users = all_users.get_users()
        
        # create kubeconfig with contexts for all users
        all_contexts.init()
        all_contexts.create_kubeconfigs(self.config['kubeconfig'],self.users)
        self.last_login_time = time.time()
        self.kubeconfigs = all_contexts.kubeconfigs
    
    def init(self):
        pass

# make it singleton
global_data = GlobalData()

if __name__ == "__main__":
    global_data.load_data('/Users/qili/git/svt/reliability/config/enhance_reliability.yaml')
    print(global_data.config)