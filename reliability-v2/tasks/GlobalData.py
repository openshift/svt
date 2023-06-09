import logging
import time
import os
import yaml
from concurrent.futures import ThreadPoolExecutor
from utils.cli import oc
from users.Contexts import all_contexts
from users.Users import all_users
from users.Session import Session
from tasks.ScheduledTasks import scheduledTasks
from integrations.SlackIntegration import slackIntegration
from integrations.KrakenIntegration import KrakenIntegration
import uuid

# a class to hold config, users, kubeconfigs
class GlobalData:

    def __init__(self):
        self.config = {}
        self.users = {}
        self.kubeconfigs = {}
        self.logger = logging.getLogger('reliability')
        self.uuid = uuid.uuid4()
        
    def valid_config(self, config):
        try:
            self.config = config["reliability"]
            # validate kubeconfig file
            kubeconfig = self.config["kubeconfig"]
            if os.path.isfile(kubeconfig):
                self.kubeconfig = kubeconfig
            else:
                self.logger.error(f"kubeconfig file '{kubeconfig}' does not exist.")
                return False

            # validate user file
            user_file = self.config['users'][1]["user_file"]
            if os.path.isfile(user_file):
                    self.user_file = user_file
            else:
                self.logger.error(f"user_file '{user_file}' does not exist. Please check the config file.")
                return False

            # validate admin_file
            admin_file = self.config['users'][0]["admin_file"]
            if os.path.isfile(admin_file):
                self.admin_file = admin_file
            else:
                self.logger.error(f"admin_file '{admin_file}' does not exist. Please the your config file.")
                return False

        except KeyError as e:
            self.logger.error(f"config file should contain key {e}.")
            return False
        return True
    
    def load_config(self,config_file):
        if os.path.isfile(config_file):
            with open(config_file) as f:
                config = yaml.safe_load(f)
                if not self.valid_config(config):
                    return False
        else:
            self.logger.error(f"config file '{config_file}' does not exist.")
            return False
        return True
        
    def init_users(self):
        # load test users
        all_users.load_users(self.user_file)       
        # load admin user
        all_users.load_users(self.admin_file)

        self.users = all_users.get_users()
        
        # create kubeconfig with contexts for all users
        if all_contexts.create_kubeconfigs(self.kubeconfig,self.users):
            self.kubeconfigs = all_contexts.kubeconfigs
            return True
        else:
            self.logger.error(f"Init user failed.Reliability test stopped. Please check log for detail.")
            if slackIntegration.slack_enable:
                slackIntegration.error(f"Init user failed.Reliability test stopped. Please check log for detail.")
            return False

    def init_scheduler(self):
        # start background scheduled tasks
        scheduledTasks.start()
        scheduledTasks.scheduler.add_job(self.relogin, 'interval', minutes=60)
        self.logger.info(f"Relogin job is added with interval: minutes=60.")
        self.logger.debug(scheduledTasks.scheduler.print_jobs())

    def init_intgration(self):
        # init Slack integration
        slack_enable = self.config["slackIntegration"].get("slack_enable", False)
        slack_channel= self.config["slackIntegration"].get("slack_channel", "")
        slack_member= self.config["slackIntegration"].get("slack_member", "")
        if slack_enable:
            slackIntegration.init_slack(slack_channel, slack_member, self.uuid)
            # send start slack integration
            (server, rc)=oc("whoami --show-server", self.kubeconfig)
            (version, rc)=oc("version", self.kubeconfig)
            cluster_info = server + version if rc == 0 else "unknown"
            slackIntegration.slack_report_reliability_start(cluster_info)

        # init Ceberus integration
        self.cerberus_enable = self.config["cerberusIntegration"].get("cerberus_enable", False)
        self.cerberus_api = global_data.config["cerberusIntegration"].get("cerberus_api", "http://0.0.0.0:8080")
        self.cerberus_fail_action = global_data.config["cerberusIntegration"].get("cerberus_fail_action", "continue")

        # init Kraken integration
        kraken_enable = global_data.config["krakenIntegration"].get("kraken_enable", False)
        if kraken_enable:
            kraken_scenarios = self.config["krakenIntegration"].get("kraken_scenarios", [])
            krakenIntegration = KrakenIntegration(kraken_scenarios, self.kubeconfig)
            krakenIntegration.add_jobs(scheduledTasks.scheduler)

    # re-login all users to avoid login session token in kubeconfig expiration. The default timeout is 1 day.
    def relogin(self):
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

# make it singleton
global_data = GlobalData()

if __name__ == "__main__":
    global_data.load_config('<path to config file>')
    print(global_data.config)
