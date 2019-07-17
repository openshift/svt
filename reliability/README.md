OpenShift V4 Reliability 
===========================
Software reliability testing is a field of software testing that relates to testing a software's ability to function, given environmental conditions, for a particular amount of time.
Openshift Reliability testing is an operational testing scheme that uses a baseline work efficiency specification to evaluate the stability of openshift system in the given amount of time. The purpose is to discover problems in functionality. The baseline work efficiency specification was made up of daily tasks such as applications developing, hosting and scaling. 
<br/>

Configure (WIP)
===========================
Tasks are classified as minutely, hourly, weekly or monthly.  To each of these intervals, a real time interval is assigned.  This is done to allow assigning activities with a natural spacing while allowing for faster simulation of the activities.  Below is a sample working configuration. Note that not all fields are currently supported as this tool is a work in progress.  In particular the percentages for performing activities on a subset of the resources is not yet implemented.
```yaml
reliability:
  timeSubstitutions:
    minute: 20s
    hour: 1m
    day: 2m
    week: 3m
    month: 4m
  limits:
    maxProjects: 20
    sleepTime: 10

  appTemplates:
    - template: cakephp-mysql-example
    - template: nodejs-mongodb-example
    - template: django-psql-example
    - template: rails-postgresql-example
    - template: dancer-mysql-example
  users:
    - id: redhat
      pw: redhat
    - id: test
      pw: test
  tasks:
    minute:
      - action: check
        resource: pods
      - action: check
        resource: projects
      - action: create
        resource: projects
        quantity: 1
    hour:
      - action: check
        resource: projects
      - action: visit
        resource: apps
      - action: create
        resource: projects
        quantity: 3
      - action: scaleUp
        resource: apps
        applyPercent: 50
      - action: scaleDown
        resource: apps
        applyPercent: 100
      - action: build
        resource: apps
        applyPercent: 50
    week:
      - action: delete
        resource: projects
        applyPercent: 30
      - action: login
        resource: session
        user: kubeadmin
        password: <password>
```



Execute
===========================
1. Edit your configuration file to represent the activities to be performed
1. python reliability.py -f config_file

Logs will go to stdout and /tmp/reliability.log

Control activity execution (in script working directory):
```bash
# pause execution
touch pause
# when ready to resume
rm pause
# clean shutdown at end of next activity cycle
touch halt
```



