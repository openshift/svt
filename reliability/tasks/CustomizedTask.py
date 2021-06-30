from .GlobalData import global_data
from tasks.utils.oc import oc
import os
import logging

class OCTask():
    def __init__(self, command, kubeconfig):
        self.command = command
        self.kubeconfig = kubeconfig
        
    def execute(self):
        return oc(self.command.lstrip("oc "), self.kubeconfig)

class FileTask():
    def __init__(self, file, kubeconfig):
        self.file =file
        self.kubeconfig = kubeconfig
        self.output = []
        self.rc = 0
    def execute(self):
        with open (self.file) as f:
            for l in f.readlines():
                task = OCTask(l, self.kubeconfig)
                output, rc = task.execute()
                self.output.append(output)
                if rc != 0:
                    break
        return self.output, rc

class CustomizedTask():
    def __init__(self):
        self.output = None
        self.code = 0
        self.customized_task_succeeded = 0
        self.customized_task_failed = 0
        self.logger = logging.getLogger('reliability')

    def execute_task(self, action, kubeconfig):
        if action.startswith("oc ", 0):
            task = OCTask(action, kubeconfig)
        elif os.path.isfile(action):
            task = FileTask(action, kubeconfig)
        else:
            self.logger.warning(f"Customized action '{action}' is not supported. Provide an oc command or a file contains lines of oc command.")
            return None
        outout, rc = task.execute()
        with global_data.customized_task_lock:
            if rc == 0:
                self.customized_task_succeeded += 1
                return "Customized action succeeded for action: " + action
            else:
                self.customized_task_failed += 1
                return "Customized action failed for action: " + action

customizedTask = CustomizedTask()


if __name__ == "__main__":
    kubeconfig = "<path to kubeconfig of the cluster>"
    # oc command
    print("oc command")
    print(customizedTask.execute_task("oc get clusterversion", kubeconfig))
    # file
    print("file")
    print(customizedTask.execute_task("<path to a customized task file>", kubeconfig))
    #