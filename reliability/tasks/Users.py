import csv
import logging

class User:
    def __init__(self,name,password): 
        self.name = name
        self.password = password
        self.logger = logging.getLogger('reliability')
        self.project = ""

class Users:
    def __init__(self):
        self.users = {}
        self.logger = logging.getLogger('reliability')

    def load_users(self,user_file):
        try:
            with open(user_file) as f:
                reader = csv.reader(f)
                user_list = list(reader)
                for user_entry in user_list[0]:
                    name,password = user_entry.split(':')
                    self.users[name] = User(name,password)

        except Exception as e:
            self.logger.warning("load_users: " + user_file + " failed to load or does not exist: " + str(e))
        
        if len(self.users) == 0:
            self.logger.warning("load_users: " + user_file + " contained no users")
    
    def load_admin(self, kubeadmin_file):
        try:
            with open(kubeadmin_file) as f:
                password = f.read()
                self.users["kubeadmin"] = User("kubeadmin", password)
        except Exception as e:
            self.logger.warning("load_admin: " + kubeadmin_file + " failed to load or does not exist: " + str(e))

    def get_users(self):
        return self.users

    def init(self):
        pass

all_users=Users()
    
if __name__ == "__main__":
    all_users.init()
    all_users.load_users("/home/mifiedle/mffiedler_git/svt/reliability/config/users.spec")
    for current_name in all_users.users.keys():
        print(all_users.users[current_name].name + " " + all_users.users[current_name].password) 