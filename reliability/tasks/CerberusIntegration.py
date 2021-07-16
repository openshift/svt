import logging
import requests


class CerberusIntegration:
    def __init__(self):
        self.logger = logging.getLogger('reliability')
        self.history_failures = 0

    def get_status(self, cerberus_api):
        # Get status from cerberus api
        try:
            r = requests.get(cerberus_api)
            if r.status_code == 200:
                if "True" in r.text:
                    return "True"
                elif "False" in r.text:
                    return "False"
            else:
                return str(r.status_code)
        except Exception as e:
            self.logger.warning(f"Request to {cerberus_api} has exception. {e}")
            return e

    def save_history(self, cerberus_api, cerberus_history_file):
        # Get failures history from cerberus api
        failures = []
        update_flag = False
        try:
            history_api = cerberus_api + "/history"
            r = requests.get(history_api)
            if r.status_code == 200:
                failures = r.json()["history"]["failures"]
                failure_count = len(failures)
                # When new failures happen, write latest history to the history file.
                if failure_count > self.history_failures:
                    self.history_failures = failure_count
                    with open(cerberus_history_file, 'w', encoding='utf-8') as f:
                        f.write(r.text)
                        self.logger.info(f"Cerberus history is updated. Latest history is saved to '{cerberus_history_file}'")
        except Exception as e:
            self.logger.warning(f"{e}")
            return e

    def init(self):
        pass

cerberusIntegration = CerberusIntegration()

if __name__ == "__main__":
    cerberusIntegration = CerberusIntegration()
    print(cerberusIntegration.get_status("http://0.0.0.0:8080"))
