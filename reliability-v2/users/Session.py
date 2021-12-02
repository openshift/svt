from utils.cli import oc
import logging

class Session:
    def __init__(self):
        self.logger = logging.getLogger('reliability')

    def login(self, username, password, kubeconfig):
        retry = 10
        rc = 1
        while rc != 0 and retry > 0:
            if retry != 1:
                result, rc = oc(f"login -u {username} -p {password}", kubeconfig,ignore_slack=True)
            else:
                result, rc = oc(f"login -u {username} -p {password}", kubeconfig)
            retry -= 1
        if rc != 0:
            self.logger.error(f"Login with user {username} failed")
            self.logger.info(result)
            return False
        else:
            return True
