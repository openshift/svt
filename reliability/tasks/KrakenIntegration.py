import logging
import sys
from apscheduler.schedulers.background import BackgroundScheduler
from .GlobalData import global_data
from tasks.utils.SlackIntegration import slackIntegration
from tasks.utils.oc import shell

class KrakenIntegration:
    def __init__(self):
        self.logger = logging.getLogger('reliability')
        self.job_parameters = {}
        executors = {
            'default': {'type': 'threadpool', 'max_workers': 20},
        }
        job_defaults = {
            'coalesce': False,
            'max_instances': 1
        }
        # init scheduler to be run in background
        self.scheduler = BackgroundScheduler(executors=executors, job_defaults=job_defaults)
        self.kubeconfig = global_data.config["kubeconfig"]

        # init the command to run kraken-hub
        _,rc = shell("podman ps -l",ignore_slack=True)
        if rc ==  0:
            self.cmd = "podman"
        else:
            _,rc = shell("docker ps -l",ignore_slack=True)
            if rc ==  0:
                self.cmd = "docker"
            else:
                slackIntegration.post_message_in_slack(f"Kraken Integration failed. Please install podman or install and start docker first.")
                exit()

    def add_jobs(self):
        try:
            kraken_enable = global_data.config["krakenIntegration"].get("kraken_enable", False)
            kraken_scenarios = global_data.config["krakenIntegration"].get("kraken_scenarios", [])
        except KeyError as e:
            self.logger.error(f"[kraken Integration] config file should contain key {e}.")

        if kraken_enable:
            for kraken_scenario in kraken_scenarios:
                name = kraken_scenario.get("name", "")
                scenario = kraken_scenario.get("scenario", "")
                parameters = kraken_scenario.get("parameters", {})
                self.job_parameters[name] = parameters
                interval_unit = kraken_scenario.get("interval_unit", "")
                interval_number = kraken_scenario.get("interval_number", 0)
                start_date = kraken_scenario.get("start_date", "")
                end_date = kraken_scenario.get("end_date", "")
                timezone = kraken_scenario.get("timezone", "")
                interval = {interval_unit:interval_number}
                if start_date != "":
                    interval['start_date']= start_date
                if end_date != "":  
                    interval['end_date']= end_date
                if timezone != "": 
                    interval['timezone']= timezone
                # pass interval parameters with a map interval, pass function args as list args
                self.scheduler.add_job(self.run_kraken, 'interval', **interval, args=[name,scenario])
                self.logger.info(f"[kraken Integration] Kraken scenario '{name}' is added with interval: {interval}.")
                slackIntegration.post_message_in_slack(f"[kraken Integration] Kraken scenario '{name}' is added with interval: {interval}.")

    def start(self):
        # start the scheduler
        self.scheduler.start()
        self.logger.info("[kraken Integration] Kraken Job Scheduler started.")
        self.logger.debug(self.scheduler.print_jobs())

    def run_kraken(self, *args):
        # generate env parameters to be used in command
        name = args[0]
        scenario = args[1]
        parameters = self.job_parameters[name]
        parameter_string = ""
        for key in parameters:
            value = parameters[key]
            parameter_string = f"{parameter_string} --env {key}={value} "

        # run the Kraken-hub scenario as container
        run_result, run_rc = shell(f"{self.cmd} run --name={name} --net=host {parameter_string} -v {self.kubeconfig}:/root/.kube/config:Z -d quay.io/openshift-scale/kraken:{scenario}")
        self.logger.info(f"[kraken Integration] Kraken scenario job '{name}' is triggered.")
        slackIntegration.post_message_in_slack(f"[kraken Integration] Kraken scenario job '{name}' is triggered.")

        # get container id
        container_id = ""
        container_log = ""
        if run_rc == 0:
            # pulling image
            if "Unable to find image" in run_result: 
                container_id = run_result.splitlines()[-1]
            # no need to pull image
            else:
                container_id = run_result
            # remove '\n'
            container_id = container_id.replace("\n", "")

            # get run exit code
            # inspect_result, inspect_rc = shell(f"{self.cmd} inspect {container_id} --format " + '\"{{.State.ExitCode}}\"',ignore_slack=True)
            # sometimes the ExitCode =0 but there is error in the container log.
            # if inspect_rc != 0 or inspect_result.replace("\n", "") != "0":

            # get logs
            container_log, log_rc = shell(f"{self.cmd} logs -f {container_id}",ignore_slack=True)
            # send events to slack and wirte to log file
            log_error = ""
            if log_rc  == 0:
                for line in container_log.splitlines(True):
                    if "[ERROR]" in line:
                        log_error = f"{log_error}{line}"
                if log_error != "":
                    slackIntegration.post_message_in_slack(f"[kraken Integration] Kraken scenario job '{name}' is finished with Error.\n{log_error}")
                    self.logger.error(f"[kraken Integration] Kraken scenario job '{name}' is finished with Error.\n{log_error}")
                else:
                    slackIntegration.post_message_in_slack(f"[kraken Integration] Kraken scenario job '{name}' is finished.")
                    self.logger.info(f"[kraken Integration] Kraken scenario job '{name}' is finished.")
            else:
                self.logger.error(f"[kraken Integration] Kraken scenario job '{name}' log retrive failed.")

            # remove container
            _, rm_rc = shell(f"{self.cmd} rm {container_id}",ignore_slack=True)
            if rm_rc == 0:
                self.logger.info(f"[kraken Integration] Kraken scenario job '{name}' container is removed.")
            else:
                self.logger.error(f"[kraken Integration] Kraken scenario job '{name}' container failed to remove.")

        else:
            self.logger.error(f"container run failed for Kraken scenario job '{name}'. Result is {run_result}")

        self.logger.debug(self.scheduler.print_jobs()) 
        