import os
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError
from slack_sdk.webhook import WebhookClient
import logging
import time

class SlackIntegration:
    def __init__(self):
        self.logger = logging.getLogger('reliability')
        self.slack_enable = False
        self.slack_api_token = ""
        self.slack_webhook_url = ""
        self.slack_webhook_client = ""
        self.slack_messaging_method = ""
        self.slack_channel = ""
        self.slack_member = ""
        self.slack_web_client = None
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
        self.uuid = ""
    
    def init_slack(self, slack_channel, slack_member,uuid):
        self.slack_channel = slack_channel
        self.slack_member = slack_member
        self.uuid = uuid
        try:
            self.slack_webhook_url = os.environ["SLACK_WEBHOOK_URL"]
        except Exception as e:
            self.logger.warning("Check if SLACK_WEBHOOK_URL environment variable are correctly set. Exception: %s" % (e))
        try:
            self.slack_api_token = os.environ["SLACK_API_TOKEN"]
        except Exception as e:
            self.logger.warning("Check if SLACK_API_TOKEN environment variable are correctly set. Exception: %s" % (e))
        # disable slack ingetragion if neither SLACK_API_TOKEN and SLACK_WEBHOOK_URL are provided.
        if self.slack_api_token == "" and self.slack_webhook_url == "":
            self.logger.error("Please provide either SLACK_API_TOKEN or SLACK_WEBHOOK_URL environment variable to enable slack integration.")
            self.logger.warning("Disable slack integration.")
            self.slack_enable = False
        # if only SLACK_API_TOKEN is provided, use SLACK_API_TOKEN
        # if both SLACK_API_TOKEN and SLACK_WEBHOOK_URL are provided, SLACK_API_TOKEN takes precedence.
        elif self.slack_api_token != "":
            self.slack_messaging_method = "web_api"
            self.logger.info("SLACK_API_TOKEN is set. Slack integration method is set to 'web_api'.")
            try:
                self.slack_web_client = WebClient(token=self.slack_api_token)
                self.logger.info("Slack client created.")
                self.slack_enable = True
                self.__init_tag()
            except Exception as e:
                self.logger.warning("Couldn't create slack WebClient. Exception: %s" % (e))
                self.logger.warning("Disable slack integration.")
                self.slack_enable = False
        # if SLACK_API_TOKEN is not provided but SLACK_WEBHOOK_URL is provided, use slack webhook method.
        elif self.slack_api_token == "" and self.slack_webhook_url != "": 
            self.slack_messaging_method = "webhook"
            self.logger.info("Slack integration method is 'webhook'.")
            self.slack_webhook_client = WebhookClient(self.slack_webhook_url)
            self.logger.info("Slack webhook url is configured.")
            self.slack_enable = True
            self.__init_tag()

    # Init slack tag
    def __init_tag(self):
        if self.slack_member != "" and self.slack_messaging_method == "web_api":
            try:
                channel_members = self.__get_channel_members().get("members", [])
                if self.slack_member != "" and self.slack_member in channel_members:
                    self.slack_tag=f"<@{self.slack_member}>, "
                else:
                    self.logger.warning(f"The slack member id '{self.slack_member}' is not in slack channel '{self.slack_channel}'.")
            except Exception as e:
                self.logger.warning("Couldn't get channel members. Exception: %s" % (e))
                self.logger.warning("Disable slack integration.")
                self.slack_enable = False
        if self.slack_member != "" and self.slack_messaging_method == "webhook":
            self.slack_tag=f"<@{self.slack_member}>, "
 
    # Get members of a channel
    def __get_channel_members(self):
        return self.slack_web_client.conversations_members(
            token=self.slack_api_token,
            channel=self.slack_channel
        )
        
    # Post messages in slack
    def __send(self, slack_message, slack_notification_level):
        timestamp = (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()))
        if slack_notification_level == 'info':
            message=f"[{timestamp}] [{self.uuid}] {self.slack_tag} {slack_message}"
        if slack_notification_level == 'error':
            message=f"[{timestamp}] [{self.uuid}] {self.slack_tag} :boom: {slack_message}"
        if self.slack_messaging_method == "web_api":
            if not self.rate_limit_message(slack_message) and self.slack_enable:
                try:
                    self.slack_web_client.chat_postMessage(
                        channel=self.slack_channel,
                        text=message,
                        thread_ts=self.thread_ts
                    )
                except SlackApiError as e:
                    assert e.response["ok"] is False
                    assert e.response["error"]
                    self.logger.warning(f"slack web api got an error: {e.response['error']}")
        if self.slack_messaging_method == "webhook":
            if not self.rate_limit_message(slack_message) and self.slack_enable:
                try:
                    response = self.slack_webhook_client.send(text=message)
                    assert response.status_code == 200
                    assert response.body == "ok"
                except Exception as e:
                    self.logger.warning(f"slack webhook post had an exception: '{e}")                

    def info(self, slack_message):
        self.__send(slack_message, "info")

    def error(self, slack_message):
        self.__send(slack_message, "error")

    # Report the start of reliability test in slack channel
    def slack_report_reliability_start(self, cluster_info):
        if self.slack_enable:
            if self.slack_messaging_method == "web_api":
                timestamp = (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()))
                message=f"[{timestamp}] [{self.uuid}] {self.slack_tag} Reliability-v2 test has started on cluster: {cluster_info}"
                try:
                    response = self.slack_web_client.chat_postMessage(channel=self.slack_channel,
                        link_names=True,
                        text=message)
                    self.thread_ts = response['ts']
                except SlackApiError as e:
                    assert e.response["ok"] is False
                    assert e.response["error"]
                    self.logger.warning(f"slack web api got an error: {e.response['error']}")
                    self.logger.warning("Disable slack integration.")
                    self.slack_enable = False
            elif self.slack_messaging_method == "webhook":
                message=f"Reliability-v2 test has started on cluster: {cluster_info}"
                self.__send(message, "info")

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
