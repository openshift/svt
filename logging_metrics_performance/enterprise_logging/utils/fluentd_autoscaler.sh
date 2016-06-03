# set -x

function clean() {
    echo "deleting all fluentd and elastic search"
	oc scale dc/logging-fluentd --replicas=0

	# Kill off all the ES servers.
	oc delete rc `oc get rc | grep logging-es | cut -d' ' -f 1`
	oc delete dc `oc get dc | grep logging-es | cut -d' ' -f 1`

    # now, manually delete all pods.  fluentd shoudlnt be many, but es may have orphans...?
	for f in `oc get pods | grep logging-es | cut -d' ' -f 1 ` ; do oc delete pod $f ; done
	# for f in `oc get pods | grep fluentd | cut -d' ' -f 1 ` ; do oc delete pod $f ; done
}

POD=`oc get pods | grep kibana | cut -d' ' -f 1`

function es() { 
#	for i in `seq 1 1 $ES`; do
#		echo "Creating es: $i"
		oc process logging-deployer-template \
-v ES_CLUSTER_SIZE=$ES,KIBANA_HOSTNAME=kibana.example.com,PUBLIC_MASTER_URL=https://localhost:8443,IMAGE_VERSION=3.1.0,IMAGE_PREFIX=registry.access.redhat.com/openshift3/ | oc create -f -
#	done
#	echo "Done creating $ES Nodes... total : "
	sleep 5
	oc get pods | grep logging-es | wc -l
    oc get pods | grep logging-es
}

function report() {
	oc exec $POD -- curl --connect-timeout 2 -s -k --cert /etc/kibana/keys/cert --key /etc/kibana/keys/key https://logging-es:9200/.operations*/_count | python -mjson.tool | grep count | cut -d':' -f 2-10 
}

# Scale fluentd, and wait 1 minute to see if logs start increasing.
function scale_fluentd_and_measure_log_count() {
	oc scale dc/logging-fluentd --replicas=$FD
	date
	while [[ `oc get pods | grep logging-es | grep -v deploy | grep Running | wc -l` -lt $ES ]] ; do
		tput sc
		echo "ES: ! `oc get pods | grep logging-es | grep -v deploy | grep Running | wc -l`  >= $ES"
		tput rc;tput el
    done
	date
	while [[ `oc get pods | grep fluent | grep Running | wc -l` -lt $(( $FD - 50)) ]] ; do 
		tput sc
		echo -n "FD ! `oc get pods | grep fluent | grep Running | wc -l`  >= $(( $FD - 50)) "
		tput rc;tput el
    done

	# Take 10 measurements, from this data, we can extract rate, stability, etc...
    
	for i in `seq 1 1 10` ; do 
		cnt=`report`
		amt_es=`oc get pods | grep logging-es | grep -v deploy | grep Running | wc -l`
		amt_flu=`oc get pods | grep fluent | grep Running | wc -l`
		echo "$i: elastic_goal:$ES,fluent_goal:$FD,fluent_actual:$amt_flu,elastic_actual:$amt_es,kibana_size:$cnt"
	done
}

clean
es
if [ -z "$FD" ]; then
    echo "Need to set FD: Number of fluentds!"
    exit 1
fi  

if [ -z "$ES" ]; then
    echo "Need to set ES:Number of es nodes!"
    exit 1
fi
scale_fluentd_and_measure_log_count
echo "now cleaning..."
clean

