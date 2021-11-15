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
    
    def init(self, slack_enable, slack_channel, slack_member):
        # Init slack client
        try:
            self.slack_enable = slack_enable
            self.slack_api_token = os.environ["SLACK_API_TOKEN"]
            self.slack_channel = slack_channel
            self.slack_member = slack_member
            if self.slack_enable == True:
                if self.slack_api_token != "" and self.slack_channel != "":
                    self.slack_client = slack.WebClient(token=self.slack_api_token)
                    self.logger.info("Slack client created.")
                else:
                    self.slack_enable = False
                    self.logger.error("Couldn't create slack WebClient. Check if "
                        "'slack_api_token' and 'slack_client' are configured.")
                    self.logger.warning("Disable slack integration.")
            else:
                self.logger.info("Slack integration is disabled")

            self.init_tag()
        except Exception as e:
            self.slack_enable = False
            self.logger.error("Couldn't create slack WebClient or Slack channel not found."
                              "Check if SLACK_API_TOKEN environment variable and slack_channel"
                              " are correctly set. Exception: %s" % (e))
            self.logger.warning("Disable slack integration.")

    # Init slack tag
    def init_tag(self):
        if slackIntegration.slack_enable:
            if self.slack_member != "":
                channel_members = self.slack_client.conversations_members(token=self.slack_api_token, channel=self.slack_channel).get("members", [])
                if self.slack_member in channel_members:
                    self.slack_tag=f"<@{self.slack_member}>, "
                else:
                    self.logger.warning(f"The slack member id '{self.slack_member}' is not in slack channel '{self.slack_channel}'.")

    # Post messages in slack
    def post_message_in_slack(self, slack_message):
        timestamp = (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()))
        if slackIntegration.slack_enable:
            self.slack_client.chat_postMessage(
                channel=self.slack_channel,
                text=f"[{timestamp}] {self.slack_tag} {slack_message}",
                thread_ts=self.thread_ts
            )

    # Get members of a channel
    def get_channel_members(self):
        return self.slack_client.conversations_members(
            token=self.slack_api_token,
            channel=self.slack_channel
        )

    # Report the start of reliability test in slack channel
    def slack_report_reliability_start(self, cluster_info):
        timestamp = (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()))
        if slackIntegration.slack_enable:
            response = self.slack_client.chat_postMessage(channel=self.slack_channel,
                link_names=True,
                text=f"[{timestamp}] {self.slack_tag} Reliability test has started on cluster: {cluster_info}")
            self.thread_ts = response['ts']

slackIntegration = SlackIntegration()
