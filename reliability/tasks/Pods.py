from  .utils.oc import shell
import logging


class Pods:
    def __init__(self):
        self.logger = logging.getLogger('reliability')

    def check(self, namespace, kubeconfig):
        if namespace.startswith("all-namespaces"):
            (result, rc) = shell('oc get pods -A --kubeconfig ' + kubeconfig + '| egrep -v "Running|Complete"')
        else:
            (result, rc) = shell('oc get pods --kubeconfig ' + kubeconfig + ' -n ' + namespace + '| egrep -v "Running|Complete"')

    def init(self):
        pass
        
all_pods=Pods()
