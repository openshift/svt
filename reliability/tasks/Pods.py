from  .utils.oc import shell
import logging


class Pods:
    def __init__(self):
        self.logger = logging.getLogger('reliability')

    def check(self):
        (result, rc) = shell('oc get pods --all-namespaces| egrep -v "Running|Complete"')
        if rc != 0:
           self.logger.error("get pods: failed")

    def init(self):
        pass
        
all_pods=Pods()
