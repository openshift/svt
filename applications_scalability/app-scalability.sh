#!/bin/bash
master=
node_list=
user=
passwd=
ns=
num=
image=
node_list=
result_dir=

function container_in_single_ns {
    oc login $master -u $user -p $passwd
    oc delete project $ns
    oc new-project $ns 
    echo "{\"apiVersion\":\"v1\",\"kind\":\"ReplicationController\",\"metadata\":{\"name\":\"test-rc\"},\"spec\":{\"replicas\":$num,\"template\":{\"metadata\":{\"labels\":{\"name\":\"test-pods\"}},\"spec\":{\"containers\":[{\"image\":\"$image\",\"name\":\"test-pod\"}]}}}}" | oc create -f -
}

function container_in_different_ns {
    oc login $master -u $user -p $passwd
    for ((i=0 ; i< $num ; i++))
    do 
    new_ns=${ns}-${i}
    oc new-project ${new_ns} 
    echo "{\"apiVersion\":\"v1\",\"kind\":\"ReplicationController\",\"metadata\":{\"name\":\"test-rc-$new_ns\"},\"spec\":{\"replicas\":$num,\"template\":{\"metadata\":{\"labels\":{\"name\":\"test-pods-$new_ns\"}},\"spec\":{\"containers\":[{\"image\":\"$image\",\"name\":\"test-pod\"}]}}}}" | oc create -f - -n $new_ns
    done
}


function service_in_single_ns {
    oc login $master -u $user -p $passwd
    oc delete project $ns
    oc new-project $ns
    echo "{\"kind\":\"Pod\",\"apiVersion\":\"v1\",\"metadata\":{\"name\":\"hello-pod\",\"labels\":{\"name\":\"hello-pod\"}},\"spec\":{\"containers\":[{\"name\":\"hello-pod\",\"image\":\"$image\"}]}}" | oc create -f -
    for i in {1..1000}
        do
            echo "{\"kind\":\"Service\",\"apiVersion\":\"v1\",\"metadata\":{\"name\":\"hello-pod-$i\",\"labels\":{\"name\":\"hello-pod-$i\"}},\"spec\":{\"ports\":[{\"name\":\"http\",\"protocol\":\"TCP\",\"port\":27017,\"targetPort\":8080}],\"selector\":{\"name\":\"hello-pod\"}}}" | oc create -f -
    done
}

function service_in_different_ns {
    oc login $master -u $user -p $passwd
    for ((i=0 ; i< $num ; i++))
    do 
    new_ns=${ns}-${i}
    oc new-project ${new_ns}
    echo "{\"kind\":\"List\",\"apiVersion\":\"v1\",\"items\":[{\"apiVersion\":\"v1\",\"kind\":\"Service\",\"id\":\"external-http\",\"metadata\":{\"name\":\"external-http-$new_ns\"},\"spec\":{\"ports\":[{\"port\":10086,\"protocol\":\"TCP\",\"targetPort\":80}]}},{\"kind\":\"Endpoints\",\"apiVersion\":\"v1\",\"metadata\":{\"name\":\"external-http-$new_ns\"},\"subsets\":[{\"addresses\":[{\"ip\":\"$external_http\"}],\"ports\":[{\"port\":80,\"protocol\":\"TCP\"}]}]}]}" | oc create -f - -n $new_ns
    done
}

function check_openflow_service {
    ssh root@$master "oc get svc --all-namespaces | grep $ns"   > $result_dir/$master-service.list
    service_in_master=`cat $result_dir/$master-service.list | sed /^$/d | wc -l`
    for node in $node_list
    do
    ssh root@$node "systemctl restart openshift-node ; sleep 10"
    ssh root@$node "ovs-ofctl dump-flows br0 -O Openflow13 | grep reg0=0x. | grep -e '172.30.[0-9]\{1,3\}.[0-9]\{1,3\}'" > $result_dir/$node-service.list
    service_in_node=`cat $result_dir/$node-service.list | sed /^$/d | wc -l`
    if [ $service_in_master -eq $service_in_node ]
    then 
        echo "Services count matches!" > $result_dir/service_compare_result-$node.log
    else
        echo "Services count does not match!" > $result_dir/service_compare_result-$node.log
    fi
    done
}
   

function check_openflow_pod {
    ssh root@$master "oc get po --all-namespaces | grep $ns"    > $result_dir/$master-pod.list
    pod_in_etcd=`cat $result_dir/$master-pod.list | sed /^$/d | wc -l`
    echo > $result_dir/node-pod.list
    for node in $node_list
    do
    ssh root@$node "systemctl restart docker ; sleep 15"
    ssh root@$node "ovs-ofctl dump-flows br0 -O Openflow13 | grep reg0=0x. | grep -e '10.1.[0-9]\{1,3\}.[0-9]\{1,3\}'" >> $result_dir/node-pod.list
    done
    pod_in_node=`cat $result_dir/node-pod.list | sed /^$/d | wc -l`
    if [ $pod_in_etcd -eq $pod_in_node ]
    then
        echo "Pods count matches!" > $result_dir/pod_compare_result.log
    else
        echo "Pods count dose not match!" > $result_dir/pod_compare_result.log
    fi
}


function access_services {
    ssh root@$master "oc get svc --all-namespaces | grep $ns"  > $result_dir/${master}-service-${ns}.list
    service_ips=(`cat $result_dir/$master-service-$ns.list | awk '{print $3":"$5}' | sed 's/\/.*//'`)
    for ((i=0 ; i< $num ; i++))
    do curl -Is ${service_ips[$i]} --connect-timeout 1 | grep HTTP\/ >> $result_dir/access_service_result.log
    done
}

#function access_pods {
#TBD
#}

function check_iptables_nat {
    for node in $node_list
    do
    ssh root@$node "iptables -L -t nat | grep DNAT | grep $ns | sort " > $result_dir/$node-iptables.list
    done
}


function usage {
echo "$0  { container_in_single_ns | container_in_different_ns | service_in_single_ns | service_in_different_ns"
echo
echo "************************************"
echo
echo "container_in_single_ns:       Create a bunch of containers/pods in the same namespace and check the openflow and access the pods (Up to 200 per node)"
echo "container_in_different_ns:    Create a bunch of namespaces which contain a single container/pod and check the openflow and access the pods (Up to 200 per node)"
echo "service_in_single_ns:         Create a bunch of services in a same namespace and check the openflow/iptables and access the service from node side (Up to 1000 per node)"
echo "service_in_different_ns:      Create a bunch of namespaces which contain a single service and check the openflow/iptables and access the service from node side (Up to 1000 per node)"

echo
echo
echo "####################################"

echo
echo    "Please update the following parameters before use!!"
echo "master:       IP of the master vm"
echo "node_list:    A list of nodes, seperated by SPACE"
echo "user:         An e2e user of openshift to run the tests"
echo "passwd:       User password to login to master"
echo "ns:           Namespace or Namespace prefix to create"
echo "num:          Number of pods/services to be created"
echo "image:        Image to use for testing"
echo "result_dir:   Path to store the test results"
}

case $1 in 
        container_in_single_ns)
        container_in_single_ns
        check_openflow_pod
#        access_pods
        ;;
        container_in_different_ns)
        container_in_different_ns
        check_openflow_pod
#        access_pods
        ;;
        service_in_single_ns)
        service_in_single_ns
        check_openflow_service
        check_iptables
        access_services
        ;;
        service_in_different_ns)
        service_in_different_ns
        check_openflow_service
        check_iptables
        access_services
        ;;
        *)
        usage
esac


