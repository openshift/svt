from  .utils.oc import oc
import logging

class Session:
    def __init__(self):
        self.logger = logging.getLogger('reliability')

    def login(self, username, password, kubeconfig):
        result, rc = oc('login -u ' + username + ' -p ' + password, kubeconfig)
        if rc !=0:
            self.logger.error(f"Login with user {username} failed")
            self.logger.info(result)
            return f"Login with user {username} failed"
        else:
            return f"Login with user {username} successfully."

    def init(self):
        pass
