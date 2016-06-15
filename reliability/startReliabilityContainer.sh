#!/bin/bash
#set -x
################################################
## Auth=vlaad@redhat.com
## Desription: script to launch Reliability tests in docker container.
################################################
echo "#) Setting up test environment"
./setEnv.sh
echo "#) Running tests"
./reliabilityTests.sh start