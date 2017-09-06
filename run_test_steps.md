# Prerequisites

* Record cluster info in case that we need to fire a bug:

    ```sh
    # openshift version
    # oc version
    # docker version
    ```

* Clone this repo on every node in the cluster
* If pbench is required to collect system stats, do the following
steps when running the tests:

    ```sh
    # svt/openshift_scalability/pbench-register.sh <ips_except_master_seperated_by_space>
    # pbench-start-tools --dir=/var/lib/pbench-agent/<test_name>
    # # run test steps
    # pbench-stop-tools --dir=/var/lib/pbench-agent/<test_name>
    # pbench-postprocess-tools --dir=/var/lib/pbench-agent/<test_name>
    # pbench-copy-results
    ```

# Concurrent-Build
Run the test by:

```sh
# cd svt/openshift_performance/ci/scripts
# ./conc_builds.sh
```

Watch the results:

```sh
svt/manual.steps/conc_build_step.sh
```

There are 4 types of known error that we print only warning for.
If ant error shows up, we need to determine if it is a bug.