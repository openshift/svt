# Node Tuning Operator

## Prerequisite

OpenShift v 4.0 or higher 
Python (tested with v 2.7.5) 

## Test Suite

To run all test at once, you can use `nto_suite` python script

```bash
python nto_suite.py
```

## Test cases
### Test: Node Tuning Operator - Core functionality

#### What is tested:

- Verification that after creating new resource with 'es' label pod will be tuned
- Verification that modification of a parameter: kernel.pid_max will take effect on every node of the cluster.
- Verification that removing custom tuning take effect on every node of the cluster
- Verification number of secrets

#### How to run test:

- Login to OCP
```bash
oc login -u <user_name> -p <password>
```
- To test just run python script
```bash
python nto_test_core_functionality_is_working.py
```

#### How to recover if something goes wrong:
Script has step to cleanup after test - even when test failed, but if something unexpected happen then please follow below steps:

- Delete project:
```bash
oc delete project my-logging-project
```

- Restore default configuration:
```bash
oc delete tuned max-pid-test -n openshift-cluster-node-tuning-operator
```

### Test: Node Tuning Operator - custom tuning is working

#### What is tested:

- Verification if after creating custom tuning new tuning exists.
- Verification if after creating custom tuning new tuning applied to tuned-profiles.
- Verification if after creating custom tuning new tuning applied to tuned-recommend.
- Verification if correct nodes are tuned by new custom tuning.
- Logs verification

#### How to run test:

- Login to OCP
```bash
oc login -u <user_name> -p <password>
```
- To test just run python script
```bash
python nto_test_custom_tuning.py
```

#### How to recover if something goes wrong:
Script has step to cleanup after test - even when test failed, but if something unexpected happen then please follow below steps:

- Delete tuned:
```bash
oc delete tuned router -n openshift-cluster-node-tuning-operator
```


### Test: Node Tuning Operator - Daemon mode - label pod

#### What is tested:

- Verification if labeling pod to match one of default profile will take effect on every node of cluster

#### How to run test:

- Login to OCP
```bash
oc login -u <user_name> -p <password>
```
- To test just run python script
```bash
python nto_test_daemon_mode_label_pod.py
```

#### How to recover if something goes wrong:
Script has step to cleanup after test - even when test failed, but if something unexpected happen then please follow below steps:

- Delete tuned:
```bash
oc label pods --all tuned.openshift.io/elasticsearch-
```

### Test: Node Tuning Operator - Daemon mode - Remove pod

#### What is tested:

- Verification that after deleting labeled pod, daemon will restore default values

#### How to run test:

- Login to OCP
```bash
oc login -u <user_name> -p <password>
```
- To test just run python script
```bash
python nto_test_daemon_mode_remove_pod.py
```

#### How to recover if something goes wrong:
Script has step to cleanup after test - even when test failed, but if something unexpected happen then please follow below steps:

- Delete tuned:
```bash
oc label pods --all tuned.openshift.io/elasticsearch-
```