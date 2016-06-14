#!/bin/bash
#set -x
################################################
## Auth=vlaad@redhat.com
## Desription: Script to Test, Start, Stop, Pause, Resume the Reliability Tests.
##
################################################
if [ "${1}" == "start" ]; then
  pbench-user-benchmark -- ./invokeReliabilityTest.sh
  echo "INFO: move results"
  pbench-move-results
  echo "INFO: clear tools"
  pbench-clear-tools
  echo "INFO: reliability tests complete"
elif [ "${1}" == "test" ]; then
  ruby test.rb
  echo "INFO: Test run complete"
elif [ "${1}" == "stop" ]; then
  kill -9 $(ps -ef | grep relia.rb | grep -v grep | awk '{print $2}')
elif [ "${1}" == "pause" ]; then
  kill -STOP $(ps -ef | grep relia.rb | grep -v grep | awk '{print $2}')
elif [ "${1}" == "resume" ]; then
  kill -CONT $(ps -ef | grep relia.rb | grep -v grep | awk '{print $2}')
else
  echo "=============================================================================================================="
  echo "=============================================================================================================="
  echo "./reliabilityTests.sh start (to start the tests)"
  echo "./reliabilityTests.sh stop (to stop the tests)"
  echo "./reliabilityTests.sh pause (to pause the running tests)"
  echo "./reliabilityTests.sh resume (to resume the tests)"
  echo "=============================================================================================================="
  echo "=============================================================================================================="
fi
