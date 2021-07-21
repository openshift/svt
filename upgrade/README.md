# About Upgrade
This package is written in python and can be used to create an environment on top of an OpenShift installation. So, basically you can create any number of projects, each having any number of following objects -- ReplicationController, Pods, Services, etc..
Note : As of now it supports only - Pods, Replicationcontrollers, Services, and Templates.

# Prerequisites

upgrade.sh depends on some Python libraries that are not part of default Python installs:

```
 $ pip install -r requirements.txt
```

# Sample Command

```
 $ ./upgrade.sh <upgrade_version>

```
Note:
* For more commandline options please use the "-h" option.
* The directory "content" contains default file for all the supported object-types.
* If the "-f" option is not supplied, then the default config file is used -- pyconfig.yaml .
* For cleaning the environment, use "-d/--clean" option.
* The "-t" option ensures that cluster-loader utility won't wait till all the pods would come to running state. This is useful when we intentionally give bad pods which are bound to fail. By default the utility waits till all the pods come to running state. The long format for this flag is `--tolerate-bad-pods`.

### Sample Command
```
 $ ./upgrade.sh 4.8.1

```
