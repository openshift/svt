## metrics_checker README

### Purpose 
The **metrics_checker.py** script is a tool for verifying hawkular metrics in OpenShift.  It can be used to verify that metrics data is present in Cassandra for an arbitrary amount of time in the past.


### Running the tool


1. Create a user with cluster-admin privileges which can be used to query metrics.  Log that user in and get the login token (redhat is an example user):

```
oc adm policy add-cluster-role-to-user cluster-admin redhat
oc login -u redhat -p redhat
oc whoami -t
```

Save the value of the token

2. Create the projects and pods

3. Run metrics_checker.py - this example uses metrics buckets of 2 minutes duration and checks for data in the last 5 buckets.  See below for all flags:

**python metrics_checker.py -B <token> -p svt -H <hawkular route or internal IP> -s "-10mn" -d "120s" -b 5 -i 30**

This translates to "Check projects starting with svt.  Check past 5 2 minute buckets.  Check 5 pods at a time and repeat every 30 seconds"


### Complete metrics_checker.py flags 

```python metrics_checker.py <optional-arguments>```

- **-B** bearer token from oc whoami -t
- **-p** project prefix (possibly broken right now, but required)
- **-H** Hawkular hostname from oc get routes.  Or, internal IP of hawkular-metrics pod from oc get pods -o wide
- **-s** start time of buckets.  Example:  -10mn is 10 minutes in the past.  See:  http://www.hawkular.org/docs/rest/rest-metrics.html
- **-d** bucket duration.  See:  http://www.hawkular.org/docs/rest/rest-metrics.html
- **-b** batch size - number of pods to check.  This is a random sample of all pods that existed when the tool started
- **-i** interval - keep the tool running continuously and check at this interval, in seconds.