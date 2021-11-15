# OpenShift V4 Reliability
## Introduction
Software reliability testing is a field of software testing that relates to testing a software's ability to function, given environmental conditions, for a particular amount of time.
Openshift Reliability testing is an operational testing scheme that uses a baseline work efficiency specification to evaluate the stability of openshift system in the given amount of time. The purpose is to discover problems in functionality. The baseline work efficiency specification was made up of daily tasks such as applications developing, hosting and scaling. 

## Git
```
$ git clone git@github.com:openshift/svt.git
cd svt/reliability
```

## Install dependencies
**NOTE**: Recommended to use a virtual environment(pyenv,venv) so as to prevent conflicts with already installed packages.
```
$ pip3 install -r requirements.txt
```

## Configuration
Example [config](https://github.com/openshift/svt/blob/master/reliability/config/example_reliability.yaml). 

### Files needed

If you installed your cluster with [Flexy-install](https://mastern-jenkins-csb-openshift-qe.apps.ocp4.prod.psi.redhat.com/job/ocp-common/job/Flexy-install/), download kubeconfig, users.spec and kubeadmin-password files. If you installed cluster in other way, prepare the above files accordingly.

Replace `kubeconfig` `kubeadmin_password` and `user_file` with above files in your config file.
```yaml
reliability:
  kubeconfig: <absolute_path_to_kubeconfig>
  users:
    - kubeadmin_password: <path_to_kubeadmin-password>
    - user_file: <path_to_users.spec>
```

For more detail explaination about the configuration, please go to [Configuration Detail](#Configuration-Detail).

## Run

### Run Reliability Test
If you want to receive notifications about the start stop of the test and errors happen during the Reliability test, configure [Slack Integration](#Slack-Integration) before running the Reliability test.

If you want to leverage Cerberus to check the healthy of the cluster and take action during the Reliability test, configure [Cerberus Integration](#Cerberus-Integration) before running the Reliability test.

If you want to add [Kraken](https://github.com/cloud-bulldozer/kraken-hub) to inject errors during the Reliability test, configure [Kraken Integration](#Kraken-Integration) before running the Reliability test.

Run the test
```
python3 reliability.py -c <path to config file> -c <path to log config file> -l ./reliability.log --cerberus-history <path to file to save cerberus history is cerberus is enabled>
```
`-l` and `--cerberus-history` are optional.

Logs will go to stdout and `/tmp/reliability.log` by default if `-l` is not specified.

Cerberus history file will go to `/tmp/cerberus-history.json` by default if `--cerberus-history` is not specified.

## Control activity execution (in script working directory):
```bash
# pause execution
touch pause
# when ready to resume
rm pause
# clean shutdown at end of next activity cycle
touch halt
```

## Configuration Detail
Example [config](https://github.com/openshift/svt/blob/master/reliability/config/example_reliability.yaml). Below sections explains each part of the configuration file.

### Tasks Time Substitutions
[Tasks](#Tasks) are classified as minutely, hourly, weekly or monthly.  To each of these intervals, a real time interval is assigned.  This is done to allow assigning activities with a natural spacing while allowing for faster simulation of the activity. For example, in the following config, `day` tasks will be exectued in every 2 minutes.
```yaml
reliability:
  timeSubstitutions:
    minute: 10s
    hour: 30s
    day: 2m
    week: 3m
    month: 4m
```

### Limits
`maxProjects` limits the max project can be created during the reliability test. When the limit is reached, new project creation task will not create project until project number is below `maxProjects`.

The number depends on the size of the cluster. Recomendations can be found in the example [config](https://github.com/openshift/svt/blob/master/reliability/config/example_reliability.yaml).

`sleepTime` controls the time to wait between each task.
```yaml
reliability:
  limits:
    # total number of projects to create
    # for 3 nodes m5.xlarge cluster, 25 to 30 is recomended
    # for 5 nodes m5.xlarge cluster, 60 is recomended
    maxProjects: 25
    sleepTime: 10
```

### Cerberus Integration
Reliablity can integrate with [Cerberus](https://github.com/cloud-bulldozer/cerberus) to check the healthy of the cluster and take action accordingly during the Reliability test.

The below configuration example enables the Cerberus integration `cerberus_enable: True`, and provided the Cerberus api `cerberus_api: "http://0.0.0.0:8080"` where Reliability test can get the [Cerberus status and history](https://github.com/cloud-bulldozer/cerberus#metrics-api) from. The `cerberus_fail_action` configures how Reliability test acts when Cerberus status is False.

`pause`: When Cerberus status is 'False', pause Reliability test until Cerberus status is changed to 'True'.

`halt`: When Cerberus status is 'False', halt(end) Reliablity test.

`continue`: When Cerberus status is 'False', continue Reliability test and warn the False status in Reliability log.

**NOTE:** If cerberusIntegration is enabled, no matter which `cerberus_fail_action` is used,  when there is update of Cerberus' history, the new history will be saved to a file. See [Run](#Run) section below for configuring of the file.

**NOTE:** If Cerberus Integration is enabled, start Cerberus before reliability test.
```yaml
reliability:
  cerberusIntegration:
    # start cerberus https://github.com/cloud-bulldozer/cerberus before starting reliabiity test.
    cerberus_enable: True
    # if cerberus_enable is false, the following 2 items are ignored.
    cerberus_api: "http://0.0.0.0:8080"
    # action to take when cerberus status is False, valid data: pause/halt/continue
    cerberus_fail_action: pause
```

### Slack Integration
Receive notifications about the start stop of the Reliability test and errors happen during the Reliability test.

Set environment virable SLACK_API_TOKEN before running the test. Contact qili@redhat.com for the token.

```yaml
  slackIntegration:
    slack_enable: False
    # the ID in the example is the id of slack channel #ocp-qe-reliability-monitoring.
    slack_channel: C0266JJ4XM5
    # slack_member is optional. If provided, the notification message will @ you. 
    # you must be a member of the slack channel to receive the notification.
    slack_member: <Your slack member id>
```
In the above configuration, notifications will be sent to [#ocp-qe-reliability-monitoring](https://coreos.slack.com/archives/C0266JJ4XM5) (Channel ID: C0266JJ4XM5) in [CoreOS](coreos.slack.com) workspace, and @ the user of slack_member if you configured.

If you're in [CoreOS](coreos.slack.com) workspace, but you want to use your own slack channel, create a slack channel and install App `OCP Reliability` which already exists in CoreOS workspace.

If you want to use your own App(slack_api_token), create an [app](https://api.slack.com/apps?new_granular_bot_app=1) and add a bot to it on slack. Slack Bot Token Scopes permissions are [channels:read] [chat:write] [groups:read] [im:read] [mpim:read]. You will get a token after the app is installed to a workspace. Install the app to your channel. Set the token to SLACK_API_TOKEN environment variable.

### Kraken Integration
Configure Kraken scenario(s) to trigger error injection during the Reliability test.

The below configuration example enables the Kraken integration by setting `kraken_enable: True`.

`kraken_scenarios` defines the Kraken scenario(s) you want to run during Reliability test. For all supported Kraken scenarios, open [this link](https://github.com/cloud-bulldozer/kraken-hub/blob/main/README.md#supported-chaos-scenarios), click on a scenario, on the opened document check the image tag, it will be the scenario you want to configure. For example with `quay.io/openshift-scale/kraken:pod-scenarios`, the `scenario` should be `pod-scenarios` as the first one in the example below.

Currently the supported Kraken scenarios are:
- pod-scenarios
- node-scenarios
- zone-outages
- time-scenarios
- power-outages
- container-scenarios
- node-cpu-hog
- node-io-hog
- node-memory-hog
- namespace-scenarios
- application-outages

Refer to each Kraken scenario's document for the supported parameters, e.g [pod-scenarios](https://github.com/cloud-bulldozer/kraken-hub/blob/main/docs/pod-scenarios.md#supported-parameters). You can add any number of parameters under `parameters:`.

`interval_unit` and `interval_number` schedules how often the Kraken scenario is triggered. `start_date` and `end_date` with `timezone` are used to limit the time range to schedule the Kraken scenario. The scheduler feature makes use of [apscheduler](https://apscheduler.readthedocs.io/en/latest/modules/triggers/interval.html#module-apscheduler.triggers.interval).

Though Kraken senarios support to run the error injection multiple times with iterations or in daemon mode as parameter, in Reliability test, you may want to get notification of start and end time of each error injection, to check what errors happen in Reliability test during the error injection period. In this case, configure in Reliability test to trigger the Kraken snario with `interval_unit` and `interval_number` is recommended.

If [Slack Integration](#Slack-Integration) is enabled, notification of the Kraken scenarios' start and end time as well as result will be send to the slack channel. You can check what errors of Reliability test happen during the Kraken error injection.

```yaml
    kraken_scenarios: 
      - name: pod-scenarios_etcd
        scenario: "pod-scenarios"
        interval_unit: minutes # weeks,days,hours,minutes,seconds
        interval_number: 8
        # start_date: "2021-10-28 17:36:00" # Optional. format: 2021-10-20 10:00:00.
        # end_date: "2021-10-28 17:50:00" # Optional.
        # timezone: "Asia/Shanghai" # Optional. e.g. US/Eastern. Default is "UTC
      - name: pod-scenarios_monitoring
        scenario: "pod-scenarios"
        interval_unit: minutes # weeks,days,hours,minutes,seconds
        interval_number: 10
        parameters:
          NAMESPACE: openshift-monitoring
          POD_LABEL: app.kubernetes.io/component=prometheus
          EXPECTED_POD_COUNT: 2
      - name: node-scenarios_workerstopstart
        scenario: "node-scenarios"
        interval_unit: minutes
        interval_number: 12
        parameters:
          AWS_DEFAULT_REGION: us-east-2
          AWS_ACCESS_KEY_ID: xxxx
          AWS_SECRET_ACCESS_KEY: xxxx
          CLOUD_TYPE: aws
```

### Tasks
Tasks defines what to do for each interval.

In each task, persona and concurrency can be defined to tell Reliability test which user(s) to be used to exectue the action on the resource. For examle, the following task will have 5 developer users to check projects of their own concurrently, in 'minute' in terval (check #### Tasks timeSubstitutions).

```yaml
tasks:
    minute:
      - action: check
        resource: projects
        persona: developer
        concurrency: 5
```

Currenlty there is one admin user, defined in kubeadmin-password file, and multiple(50 in Flexy-install created cluster) developer users, defeined in users.spec.

The following resources and actions are supported now:

| action | resource | persona | concurrency | quantity | applyPercent | comment |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| check  | pod | admin/developer | 1/n | N/A | N/A | For developer, check all pods not Running or Completed under the user(s) concurrently. For admin, check all namespaces. | 
| create | project | admin/developer | 1/n | x | N/A | Create x projects for the user(s) concurrently, also create an app for each project. |
| check  | project | admin/developer | 1/n | N/A | N/A | Check projects under the user(s) concurrently. |
| modify  | project | admin/developer | 1/n | N/A | x% | Modify(create secret) for x% of the projects under the user(s) concurrently. |
| delete  | project | admin/developer | 1/n | N/A | x% | Delete x% of the projects under the user(s) concurrently. |
| visit  | apps | admin/developer | 1/n | N/A | x% | Visit x% of the apps under the user(s) concurrently. |
| build  | apps | admin/developer | 1/n | N/A | x% | Build x% of the apps under the user(s) concurrently. |
| scaleup  | apps | admin/developer | 1/n | N/A | x% | Scaleup x% of the apps under the user(s) concurrently. |
| scaledown  | apps | admin/developer | 1/n | N/A | x% | Scaledown  x% of the apps under the user(s) concurrently. |
| login  | session | admin/developer | 1/n | N/A | N/A | Login with the user(s) concurrently. |
| clusteroperators  | monitor | N/A | N/A | N/A | N/A | Check cluster operator by admin. |
| customized oc command  | customize | admin/developer | 1/n | N/A | N/A | Run the customized oc command by the user(s) concurrently. |
| file with customized oc command  | customize | admin/developer | 1/n | N/A | N/A | Run the file with customized oc command by the user(s) concurrently. |


```yaml
reliability:
  tasks:
    minute:
      # Specify an oc command to execute as 'action'.
      # Don't use command that could return '1' as expected, e.g. oc get pods -A | egrep -v "Running|Completed".
      # Use oc get pods -A | awk '$4!="Running" && $4!="Completed"' instead.
      - action: oc whoami
        resource: customize
        persona: developer
        concurrency: 5
      # Specify a file to execute as 'action'.
      # File contains lines of oc command to execute. Don't use command that could return '1' as expected.
      # - action: <path to file>
      #   resource: customize
      #   persona: admin
      #   concurrency: 1
      - action: check
        resource: pods
        persona: admin
        concurrency: 1
      - action: check
        resource: projects
        persona: developer
        concurrency: 5
    hour:
      - action: check
        resource: projects
        persona: developer
        concurrency: 5
      - action: create
        resource: projects
        quantity: 2
        persona: developer
        concurrency: 5
      - action: visit
        resource: apps
        applyPercent: 100
        persona: user
        concurrency: 10
      - action: scaleUp
        resource: apps
        applyPercent: 50
        persona: developer
        concurrency: 3
      - action: scaleDown
        resource: apps
        applyPercent: 50
        persona: developer
        concurrency: 1
      - action: build
        resource: apps
        applyPercent: 33
        persona: developer
        concurrency: 2
      - action: modify
        resource: projects
        applyPercent: 25
        persona: developer
        concurrency: 2
      - action: clusteroperators
        resource: monitor
    week:
      - action: delete
        resource: projects
        applyPercent: 33
        persona: developer
        concurrency: 5
      - action: login
        resource: session
        persona: developer
        concurrency: 5

```





