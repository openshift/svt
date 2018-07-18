#!/bin/bash

set -e

readonly NAMESPACE=${1}
readonly ITERATION=${2}
readonly TMP_FOLDER=${3}

output_dir=$4

readonly DATA_DIR=/data

echo "NAMESPACE: ${NAMESPACE}"
echo "ITERATION: ${ITERATION}"
echo "TMP_FOLDER: ${TMP_FOLDER}"
echo "output_dir: ${output_dir}"

readonly AMQ_PERF_POD=$(oc get pod -n ${NAMESPACE} | grep -v deploy | grep amq-perf | awk '{print $1}')
readonly AMQ_SVC_IP=$(oc get svc -n ${NAMESPACE} | grep 61616 | grep broker-amq-tcp | awk '{print $3}')
readonly PRODUCER_FILE_NAME=JmsProducer_numClients1_numDests1_all.xml
readonly CONSUMER_FILE_NAME=JmsConsumer_numClients1_numDests1_all.xml

for i_index in $(seq 1 ${ITERATION});
do
  echo "${NAMESPACE} iteration: ${i_index}"
  echo "$(date '+%Y-%m-%d %H:%M:%S') ${NAMESPACE}: sleep 30 ..."
  sleep 30
  oc exec -n ${NAMESPACE} "${AMQ_PERF_POD}" -- mvn -f ./activemq-perftest/pom.xml -Dmaven.repo.local=/repo activemq-perf:consumer -Dfactory.brokerURL=tcp://${AMQ_SVC_IP}:61616 -Dfactory.userName=redhat -Dfactory.password=redhat -DsysTest.reportDir=${DATA_DIR}/ -Dconsumer.durable=true -Dfactory.clientID=my-test-consumer -Dconsumer.destName=topic://TEST.FOO &
  oc exec -n ${NAMESPACE} "${AMQ_PERF_POD}" -- mvn -f ./activemq-perftest/pom.xml -Dmaven.repo.local=/repo activemq-perf:producer -Dfactory.brokerURL=tcp://${AMQ_SVC_IP}:61616 -Dfactory.userName=redhat -Dfactory.password=redhat -DsysTest.reportDir=${DATA_DIR}/ -Dproducer.deliveryMode=persistent -Dfactory.clientID=my-test-producer -Dproducer.destName=topic://TEST.FOO &
  wait
  oc exec -n ${NAMESPACE} "${AMQ_PERF_POD}" -- cat ${DATA_DIR}/${PRODUCER_FILE_NAME} > ${output_dir}/result_${NAMESPACE}_${i_index}_${PRODUCER_FILE_NAME} 2>&1
  oc exec -n ${NAMESPACE} "${AMQ_PERF_POD}" -- cat ${DATA_DIR}/${CONSUMER_FILE_NAME} > ${output_dir}/result_${NAMESPACE}_${i_index}_${CONSUMER_FILE_NAME} 2>&1
done


