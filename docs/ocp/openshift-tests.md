# OpenShift extended test suite

More information and source code on [github](https://github.com/openshift/origin/tree/master/test/extended)

##  Running the latest version of openshift-tests

* Go to [quay.io](https://quay.io/repository/openshift/origin-tests?tab=tags) and check the latest available version
* Get image_id

```bash
export IMAGE_ID=$(docker create quay.io/openshift/origin-tests:<available_version>)
# ex.
# export IMAGE_ID=$(docker create quay.io/openshift/origin-tests:v4.0)
echo $IMAGE_ID
docker images
docker ps -a 
# you'll see that image was run and no longer running
# IMAGE_ID is the ID of running image origin-tests
```
* Copy binary file

```bash
docker cp $IMAGE_ID:/bin/openshift-tests .
cp openshift-tests /usr/bin
which openshift-tests
```

* Now you can run test from command line using `openshift-tests` command

To run whole suite run command:

```bash
openshift-tests run
```

To run specific test run command;

```bash
openshift-tests run-test <name_of_test>
```