## ocp_logtest README

### Purpose 
The **ocp_logtest.py** script is a flexible tool for creating pod logs in OpenShift.  It can log random or fixed test for any given line/word sizes and at any given rate.  It can run forever, for a set number of messages or for a set period of time.

Also included are a docker configuration to run the tool in a container along with OpenShift templates to create a pod running the container and create a replication controller to control the lifecycle of the pods.

Finally it includes a sample [cluster-loader](https://github.com/openshift/svt/blob/master/openshift_scalability/README.md) configuration to create projects running these pods from **cluster_loader**.


### Running the tool

**Projects and applicatons:**  It is recommended that [cluster-loader](https://github.com/openshift/svt/blob/master/openshift_scalability/README.md) be used to create the projects, pods and replication controllers to run ocp_logtest.py  

An example cluster-loader config that works with ocp_logtest.py is [ocp-logtest.yaml](https://github.com/openshift/svt/blob/master/openshift_scalability/config/ocp-logtest.yaml)

1. Edit **svt/openshift_scalability/config/ocp-logtest.py** if you want to change the parameters for the logtest pods.  The following parameters are supported:

LOGTEST_IMAGE:  logtest image built with the content/logtest Dockerfile, default is **docker.io/mffiedler/ocp-logtest:latest**

INITIAL_FLAGS:  Initial flags to pass to ocp_logtest.py, default is **"--num-lines 0 --line-length 200 --word-length 9 --rate 60 --fixed-line\n"**

REPLICAS:  Number of replicas of the logtest pod to start, default is **1**

PLACEMENT: Value of the placement tag to control which nodes the pods run on, default is **logtest**.  This would include nodes labelled with "placement=logtest"

2. Run **cluster_loader** against the file:

**./cluster_loader.py -f config/ocp-logtest.py**

3. Verify by listing the logtest pods and tailing the logs
```
oc get pods -n logtest0 -o wide (note hostname where pod is running)

oc logs -f <podname> (verify logs are shown)

login to the host where the pod is running and verify the logs are going to journald (or wherever docker logging is configured for)
```
### Complete ocp_logtest.py flags 

```python ocp_logtest.py <optional-arguments>```

- --time how long to run for in seconds.  0 means run forever.  Not compatible with --num-lines.  No default
- *--num-lines* number of lines to generate.  Not compatible with *--time* .  Default is 0
- *--text-type* random or input.   Generate random text or read text from the input file specified by *--file*.  Default is random
- *--line-length* length of each line. Default is 100
- *--word-length* length of each word.  Only valid with random text. Default is 9
- *--fixed-line* true or false - repeat the same line of text over and over or use new text for each line. Default is false
- *--rate* lines per minute. Default is 10.0
- *--file* file to read text from.  A sample.txt is included in the default docker image.  If running in a pod, a new image with the file should be built. No default.

If no parameters are specified, it is equivalent to:

```python ocp_logtest.py --text-type random --line-length 100 --word-length 9 --fixed-line false --rate 10.0 --time 0```

### Examples

#### Run at 100 random lines per second with 200 character lines for 1 hour

```python ocp_logtest.py --line-length 200 --time 3600 --rate 100 ```

#### Run pulling text from the file sample.txt.  Use defaults for rate, line-length, etc

```python ocp_logtest.py --text-type=input --file sample.txt```

#### Run the same random line with a word size of 2 at a rate of 1000 lines per minute forever

```python ocp_logtest.py --fixed-line --word-length 2 --rate 1000 --time 0```


