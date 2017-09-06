#!/bin/bash -e
#set -x
ts() {
  date +"%Y-%m-%d_%H-%M-%S"
}
producer_pod_name=`oc get pods --namespace=stac --selector="name=producer" --no-headers -o wide | awk '{print $1}'`
consumer_pod_name=`oc get pods --namespace=stac --selector="name=consumer" --no-headers -o wide | awk '{print $1}'`
# get producer and consumer pod ips
producer=`oc get pods --namespace=stac --selector="name=producer" --no-headers -o wide | awk '{print $6}'`
consumer=`oc get pods --namespace=stac --selector="name=consumer" --no-headers -o wide | awk '{print $6}'`

oc exec $producer_pod_name -c producer -it -- /bin/bash -c 'source ~/.bashrc;sed -i 's/producer1=.*/producer1=$producer/' run_common.sh'
oc exec $producer_pod_name -c producer -it -- /bin/bash -c 'source ~/.bashrc;sed -i 's/consumer1=.*/consumer1=$consumer/' run_common.sh'
oc exec $producer_pod_name -c producer -it -- /bin/bash -c 'source ~/.bashrc;sed -i 's/ADAPTER_PRODUCER_LISTEN_ADDR=.*/ADAPTER_PRODUCER_LISTEN_ADDR=$producer/' common_tcp.sh'
oc exec $producer_pod_name -c producer -it -- /bin/bash -c 'source ~/.bashrc;sed -i 's/ADAPTER_CONSUMER_LISTEN_ADDR=.*/ADAPTER_CONSUMER_LISTEN_ADDR=$consumer/' common_tcp.sh'
oc exec $producer_pod_name -c producer -it -- /bin/bash -c 'ps ax | grep udp | grep -v grep|awk "{print $1}" | xargs kill -9 2> /dev/null || true'
oc exec $consumer_pod_name -c consumer -it -- /bin/bash -c 'ps ax | grep udp | grep -v grep|awk "{print $1}" | xargs kill -9 2> /dev/null || true'
oc exec $producer_pod_name -c producer -it -- /bin/bash -c 'source ~/.bashrc;./runTest.sh PINGPONG 1'
csv_file_name=consolidatedResults_`ts`.csv
oc exec $producer_pod_name -c producer -it -- /bin/bash -c 'source ~/.bashrc;../bin/linux2.6-x86_64-gcc4.1.2-libc2.5/stac.n.1.create_consolidated_results -i /capture/n/orchestration/stats.udp-tcp-sock -s PINGPONG -r 1 -o /capture/'$csv_file_name' -b ../bin/linux2.6-x86_64-gcc4.1.2-libc2.5'
echo " "
echo " "
echo "       TEST COMPLETE: Final results are at $producer:/tmp/consolidatedResults_$csv_file_name     "
echo " "
echo " "
