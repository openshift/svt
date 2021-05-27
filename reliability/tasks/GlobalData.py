from ReliabilityConfig import ReliabilityConfig
from tasks.Users import all_users, User
from tasks.Contexts import all_contexts
import logging

# a class to hold shared data, config, users, kubeconfigs
class GlobalData:

    def __init__(self):
        self.config = None
        self.users = {}
        self.kubeconfigs = {}
        self.logger = logging.getLogger('reliability')
    
    def load_data(self, config_file):
        # load config
        rc = ReliabilityConfig(config_file)
        rc.load_config()
        self.config = rc.config['reliability']
        
        # load all developer users
        all_users.init()
        all_users.load_users(self.config['users'][2]["user_file"])
        self.users = all_users.get_users()
        
        # add admin user
        admin = User(self.config["users"][0]["admin_user"]
            ,self.config["users"][1]["admin_password"])
        self.users[self.config["users"][0]["admin_user"]] = admin
        
        # create kubeconfig with contexts for all users
        all_contexts.init()
        all_contexts.create_kubeconfigs(self.config['kubeconfig'],self.users)
        self.kubeconfigs = all_contexts.get_kubeconfigs()
    
    def init(self):
        pass

# make it singleton
global_data = GlobalData()

if __name__ == "__main__":
    global_data.load_data('/Users/qili/git/svt/reliability/config/enhance_reliability.yaml')
    print(global_data.config)