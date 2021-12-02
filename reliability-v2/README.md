# OpenShift V4 Reliability - V2
## Introduction
Software reliability testing is a field of software testing that relates to testing a software's ability to function, given environmental conditions, for a particular amount of time.
Openshift Reliability testing is an operational testing scheme that uses a baseline work efficiency specification to evaluate the stability of openshift system in the given amount of time. The purpose is to discover problems in functionality. The baseline work efficiency specification was made up of daily tasks such as applications developing, hosting and scaling. 

Reliability-v2 can simulate real world by concurrently running different tasks by multiple groups and users. 

## Git
```
$ git clone git@github.com:openshift/svt.git
cd svt/reliability-v2
```

## Install dependencies
**NOTE**: Recommended to use a virtual environment(pyenv,venv) so as to prevent conflicts with already installed packages.
```
$ pip3 install -r requirements.txt
```

## Configuration
Example [config](https://github.com/openshift/svt/blob/master/reliability-v2/config/example_reliability.yaml). 

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

#### Run the test
```
python3 reliability.py -c <path to config file> -l <path to log config file> --cerberus-history <path to file to save cerberus history is cerberus is enabled>
```
`-l` and `--cerberus-history` are optional.

Logs will go to stdout and `/tmp/reliability.log` by default if `-l` is not specified.

Cerberus history file will go to `/tmp/cerberus-history.json` by default if `--cerberus-history` is not specified.

#### Integration
[Slack Integration](#Slack-Integration) 

If you want to receive notifications about the start stop of the test and errors happen during the Reliability test, configure Slack Integration before running the Reliability test.

[Cerberus Integration](#Cerberus-Integration) 

If you want to leverage Cerberus to check the health of the cluster and take action during the Reliability test, configure Cerberus Integration before running the Reliability test.

[Kraken Integration](#Kraken-Integration)

If you want to add [Kraken](https://github.com/cloud-bulldozer/kraken-hub) to inject chaos during the Reliability test, configure Kraken Integration before running the Reliability test.

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
Example [config](https://github.com/openshift/svt/blob/master/reliability-v2/config/example_reliability.yaml). Below sections explains each part of the configuration file.

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
`kraken_scenarios` defines the [Kraken scenario(s)](https://github.com/cloud-bulldozer/kraken-hub/blob/main/README.md#supported-chaos-scenarios) you want to run during Reliability test. Refer to each Kraken scenario's document for the supported `parameters`, e.g [pod-scenarios](https://github.com/cloud-bulldozer/kraken-hub/blob/main/docs/pod-scenarios.md#supported-parameters).

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

### Groups and Tasks
Groups define user groups. It simulate a number of users that have the similar behavior. 

Tasks define the tasks to do for the users in each group.

In the below example, it defines a group `developer-1`. `Users` in the group are 10 `developer` users as defined in `persona`. The group has some `tasks`. The 10 users will be run concurrently, each user will execute the tasks for 2 loops. There will be 60 seconds as `trigger` between each loop. Between each task, there will be 10 seconds as `interval`. Each user will delay the execution by jitter seconds at most, this is to add random to this group, so that at any given time different users could execute different tasks.

For tasks, `oc` `kubeconfig` shell and `func` are supported.

```yaml
reliability:
  groups:
      - name: admin-1
      # 'admin', 'developer' are supported.
      persona: admin
      # concurrent users to run the group. For admin, only 1 is supported.
      users: 1
      # run group for loops times. integer > 0 or 'forever', default is 1.
      loops: forever
      # wait trigger seconds between each loop
      trigger: 600
      # delay the group execution by jitter seconds at most. Default is 0.
      jitter: 60
      # wait interval seconds between tasks.
      interval: 10
      tasks: 
        - func check_operators
        - oc whoami --show-server
        - kubectl get pods -A -o wide | egrep -v "Completed|Running"
        - pwd

    - name: developer-1
      persona: developer
      users: 2
      loops: 10
      trigger: 60
      jitter: 60
      interval: 10
      tasks:
        - func delete_all_projects # clear all projects
        - func new_project 2 # new 2 projects
        - func check_all_projects # check all project under this user
        - func load_app 2 10 # load apps in 2 namespaces with 10 clients for each
        - func new_app 2 # new app in 2 namespaces
        - func build 1 # build app in 1 namespace
        - func scale_up 2 # scale up app in 2 namespaces
        - func scale_down 1 # scale down app in 2 namespaces
        - func check_pods 2 # check pods in 2 namespaces 
        - func delete_project 2 # delete project in 2 namespaces
```

Currenlty there is one admin user, defined in kubeadmin-password file, and multiple(50 in Flexy-install created cluster) developer users, defeined in users.spec.

The following funcs are supported now:

| func | parameters | persona | comment |
| ---- | ---- | ---- | ---- |
| delete_all_projects  | N/A | developer | delete all projects for a user | 
| new_project | number of projects | developer | Create n projects for the user|
| check_all_projects  | N/A | developer | Check projects under the user|
| new_app  | number of projects | developer | New an app under each project|
| load_app  | number of projects number of clients | developer | Load an app under each project with a number of clients|
| build  | number of projects | developer | Build under each project|
| scale_up  | number of projects | developer | Scaleup the deployment from 1 to 2 under each project|
| scale_down  | number of projects | developer | Scaledown the deployment from 2 to 1 under each project|
| check_pods  | number of projects | developer | Check pods under each project|
| delete_project  | number of projects | developer | Delete each project|
| check_operators  | N/A | admin | Check Degraded operators|




