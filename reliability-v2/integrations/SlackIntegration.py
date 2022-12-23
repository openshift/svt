import os
import slack
import logging
import time

class SlackIntegration:
    def __init__(self):
        self.logger = logging.getLogger('reliability')
        self.slack_enable = False
        self.slack_api_token = ""
        self.slack_channel = ""
        self.slack_member = ""
        self.slack_client = None
        self.slack_tag = ""
        self.thread_ts = None
        self.rate_limit = {}
        self.rate_limit_number = 2
        self.rate_limit_interval = 3600
        self.limited_messages = ("Unable to connect to the server: dial tcp",
        "Unable to connect to the server: dial tcp: lookup",
        "error: You must be logged in to the server (Unauthorized)",
        "Result: Error from server (AlreadyExists): project.project.openshift.io",
        "load_app: visit route")
    
    def init_slack_client(self, slack_channel, slack_member):
        # Init slack client
        try:
            self.slack_api_token = os.environ["SLACK_API_TOKEN"]
            self.slack_channel = slack_channel
            self.slack_member = slack_member
            if self.slack_api_token != "" and self.slack_channel != "":
                self.slack_client = slack.WebClient(token=self.slack_api_token)
                self.logger.info("Slack client created.")
                self.slack_enable = True
            else:
                self.slack_enable = False
                self.logger.error("Couldn't create slack WebClient. Check if "
                    "'slack_api_token' and 'slack_client' are configured.")
                self.logger.warning("Disable slack integration.")

            self.__init_tag()
        except Exception as e:
            self.slack_enable = False
            self.logger.error("Couldn't create slack WebClient or Slack channel not found."
                              "Check if SLACK_API_TOKEN environment variable and slack_channel"
                              " are correctly set. Exception: %s" % (e))
            self.logger.warning("Disable slack integration.")

    # Init slack tag
    def __init_tag(self):
        if self.slack_member != "":
            channel_members = self.__get_channel_members().get("members", [])
            if self.slack_member in channel_members:
                self.slack_tag=f"<@{self.slack_member}>, "
            else:
                self.logger.warning(f"The slack member id '{self.slack_member}' is not in slack channel '{self.slack_channel}'.")
 
    # Get members of a channel
    def __get_channel_members(self):
        return self.slack_client.conversations_members(
            token=self.slack_api_token,
            channel=self.slack_channel
        )
        
    # Post messages in slack
    def info(self, slack_message):
        if not self.rate_limit_message(slack_message):
            timestamp = (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()))
            try:
                self.slack_client.chat_postMessage(
                    channel=self.slack_channel,
                    text=f"[{timestamp}] {self.slack_tag} {slack_message}",
                    thread_ts=self.thread_ts
                )
            except Exception as e:
                self.logger.warning(f"post_info_to_slack had exception: '{e}")

    def error(self, slack_message):
        if not self.rate_limit_message(slack_message):
            timestamp = (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()))
            try:
                self.slack_client.chat_postMessage(
                    channel=self.slack_channel,
                    text=f"[{timestamp}] {self.slack_tag} :boom: {slack_message}",
                    thread_ts=self.thread_ts
                )
            except Exception as e:
                self.logger.warning(f"post_error_to_slack had exception: '{e}")

    def debug(self, slack_message):
        if not self.rate_limit_message(slack_message):
            timestamp = (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()))
            try:
                self.slack_client.chat_postMessage(
                    channel=self.slack_channel,
                    text=f"[{timestamp}] {self.slack_tag} :bug: {slack_message}",
                    thread_ts=self.thread_ts
                )
            except Exception as e:
                self.logger.warning(f"post_error_to_slack had exception: '{e}")

    # Report the start of reliability test in slack channel
    def slack_report_reliability_start(self, cluster_info):
        timestamp = (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()))
        if self.slack_enable:
            response = self.slack_client.chat_postMessage(channel=self.slack_channel,
                link_names=True,
                text=f"[{timestamp}] {self.slack_tag} Reliability-v2 test has started on cluster: {cluster_info}")
            self.thread_ts = response['ts']

    # Rate limit the number of messages 
    def rate_limit_message(self,message):
        for limited_message in self.limited_messages:
            if limited_message in message:
                if self.rate_limit.get(message)!= None:
                    new_time = time.time()
                    self.rate_limit[message]["number"] += 1
                    if new_time - self.rate_limit[message]["time"] > self.rate_limit_interval:
                        self.rate_limit[message]["number"] = 1
                        self.rate_limit[message]["time"] = time.time()
                        return False
                    else:
                    # Limit the message if it is sent more than 2 times
                        if self.rate_limit[message]["number"] > self.rate_limit_number:
                            self.logger.warning(f"Limit message for greater than {self.rate_limit_number} times in {self.rate_limit_interval} seconds")
                            return True
                        else:
                            return False
                else:
                    self.rate_limit[message] = {}
                    self.rate_limit[message]["number"] = 1
                    self.rate_limit[message]["time"] = time.time()
                    return False
        return False

slackIntegration = SlackIntegration()
