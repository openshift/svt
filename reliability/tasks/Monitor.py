from .GlobalData import global_data
from .utils.oc import oc
import logging
import yaml

class Monitor:
    def __init__(self):
        self.logger = logging.getLogger('reliability')

    def check_operators(self):
        # This operation can only be done by admin user
        kubeconfig = global_data.kubeconfigs["kubeadmin"]
        (result, rc) = oc("get clusteroperators --kubeconfig " + kubeconfig + " -o yaml")
        if rc != 0:
            self.logger.error("get clusteroperators: failed")
        else:
            operator_info = yaml.safe_load(result)
            for item in operator_info["items"]:
                name = item["metadata"]["name"]
                for condition in item["status"]["conditions"]:
                    if condition["type"] == "Degraded" and condition["status"] == "True":
                        self.logger.error("operator degraded: " + name)
    
    def init(self):
        pass
    
monitor = Monitor()

if __name__ == "__main__":
    all_monitor.check_operators()
