from  .utils.oc import oc
import logging


class Pods:
    def __init__(self):
        self.logger = logging.getLogger('reliability')

    def check(self):
        (result, rc) = oc("get pods --all-namespaces")
        if rc != 0:
           self.logger.error("get pods: failed")

    def init(self):
        pass
        
all_pods=Pods()
