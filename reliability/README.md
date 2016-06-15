OpenShift V3 Reliability 
===========================
Software reliability testing is a field of software testing that relates to testing a software's ability to function, given environmental conditions, for a particular amount of time.
Openshift Reliability testing is an operational testing scheme that uses a baseline work efficiency specification to evaluate the stability of openshift system in the given amount of time. The purpose is to discover problems in functionality. The baseline work efficiency specification was made up of daily tasks such as applications developing, hosting and scaling. 
<br/>

Design
===========================
Openshift Task are classified by hourly, daily, weekly and monthly and run in different termly.  The tasks include user creation ,project creation, Project modification. openshift monitor and log analysis. System log and Operation logs will be analysed regularly. Jobs elapsed time, openshift process memory usage, openshift process CPU usage, system memory and system CPU usage are gathered.<br/>
<br/>
Serveral tasks are defined as following<br/>
      create "10" user <br/>
      login "100%" users <br/>
      create "10" projects <br/>
      create "10" applications <br/>
      modify "100%" projecs <br/>
      scale up "100%" appplications <br/>
      scale down "100%" app <br/>
      delete "100%" project <br/>
      delete "all" user <br/>
      check project info <br/>
      clean environment <br/>
      monitor openshift <br/>
      monitor masters <br/>
      monitor nodes <br/>
      monitor etcds <br/>
<br/>

A bundle of tasks are grouped by time files under config/tasks, these files will be executed during testing <br/>

For example:<br/>
*cat config/tasks/day* <br/>
*login "100%" users*<br/>
*create "5" user*<br/>
*visit "100%" app*<br/>
*modify "20%" project*<br/>
*scale up "80%" app*<br/>
*check project info*<br/>

Execute
====================
1) pre execution<br/>
  edit config/config.yaml <br/>
  sh setEnv.sh<br/>
  define tasks under config/tasks/<br/>
2) run testing<br/>
   ./reliabilityTests.sh start (to start the tests)<br/>
   ./reliabilityTests.sh stop (to stop the tests)<br/>
   ./reliabilityTests.sh pause (to pause the running tests)<br/>
   ./reliabilityTests.sh resume (to resume the tests)<br/>
3) post execution<br/>
   The log are under logs/<br/>
   analyst directory has a parse-logs.sh script which parses data and creates results directory,/<br/>
   results directory will have csv files with CPU and Memory consumptions and all the activities done by tests./<br/>
   PBench results are available on server configured in /opt/pbench-agent/config/pbench-agent.conf/<br/>
<br/>
Execute in Docker Container
====================
1) pre execution<br/>
   clone the git repo on docker host<br/>
   edit config/config.yaml <br/>
   define tasks under config/tasks/<br/>
2) run testing<br/>
   build image using Dockerfile `docker build -t <image_name>:<version>`
   run image using following command
   `docker run -v <path_to_svt_clone>:/root/svt -v <ssh_key1>:/root/.ssh/id_rsa -v <updated_pbench-agent.conf>:/opt/pbench-agent/config/pbench-agent.conf -v <ssh_key2>:/opt/pbench-agent/id_rsa -t -i <image_name>:<version> <br/>
   ssh_key1=ssh key for nodes and master hosts
   ssh_key2=ssh key for pbench server to move results.`
3) post execution<br/>
   The log are under logs/<br/>
   analyst directory has a parse-logs.sh script which parses data and creates results directory,/<br/>
   results directory will have csv files with CPU and Memory consumptions and all the activities done by tests./<br/>
   PBench results are available on server configured in /opt/pbench-agent/config/pbench-agent.conf/<br/>
<br/>
TODO
======================
crontab support<br/><br/>
GUI configure<br/><br/>
Cloud running<br/><br/>
<br/>
Reference
======================
1. Crontab https://bitbucket.org/dbenamy/devcron#egg=devcron<br/><br/>
2. http://www.pcp.io/docs/installation.html<br/><br/>
