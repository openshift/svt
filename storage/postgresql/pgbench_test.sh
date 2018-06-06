#!/bin/bash 

# Script to to run pgbench load test against postgresql pod in kubernetes/Openshift
  
opts=$(getopt -q -o n:t:e:v:m:i:r: --longoptions "namespace:,transactions:,template:,volsize:,memsize:,iterations:,mode:,resultdir:,clients:,scaling:,threads:,storageclass:" -n "getopt.sh" -- "$@");

if [ $? -ne 0 ]; then
    printf -- "$*\n"
    printf "\n"
    printf "You specified an invalid option\n"
    printf "\tThe following options are available:\n\n"
    printf -- "\t\t-n --namespace - name for new namespace to create pod inside\n"
    printf -- "\t\t-t --transactions - the number pgbench transactions\n"
    printf -- "\t\t   --scaling - pgbench scaling factor\n"
    printf -- "\t\t-e --template -  what template to use\n"
    printf -- "\t\t-v --volsize - size of volume for database\n"
    printf -- "\t\t-m --memsize - size of memory to assign to postgresql pod\n"
    printf -- "\t\t-i --iterations - how many iterations of test to execute\n"
    printf -- "\t\t --mode - what mode to run: cnsfile or cnsblock, or otherstorage\n"
    printf -- "\t\t-r --resultdir - name of directory where to place pgbench results\n"
    printf -- "\t\t --clients - number of pgbench clients\n"
    printf -- "\t\t --threads - number of pgbench threads\n"
    printf -- "\t\t --storageclass - name of storageclass to use to allocate storage\n"
    exit 1 
fi

eval set -- "$opts";
echo "processing options" 

while true; do
    case "$1" in
        -n|--namespace)
            shift;
            if [ -n "$1" ]; then
                namespace="$1"
                shift;
            fi
        ;;
        -t|--transactions)
            shift;
            if [ -n "$1" ]; then 
                transactions="$1"
                shift;
            fi 
        ;; 
        -e|--template)
            shift;
            if [ -n "$1" ]; then 
                template="$1"
                shift;
            fi
        ;; 
        -v|--volsize)
            shift;
            if [ -n "$1" ]; then 
                volsize="$1"
                shift;
            fi
        ;;
        -m|--memsize)
            shift;
            if [ -n "$1" ]; then 
                memsize="$1"Mi
                shift;
            fi
        ;;
        -i|--iterations)
            shift;
            if [ -n "$1" ]; then 
                iterations="$1"
                shift;
            fi
        ;;
        --mode)
            shift; 
            if [ -n "$1" ]; then 
                mode="$1"
                shift
            fi
        ;;
        -r|--resultdir)
            shift; 
            if [ -n "$1" ]; then 
                resultdir="$1"
                mkdir -p $resultdir 
                shift; 
            fi 
        ;; 
        --clients)
            shift;
            if [ -n "$1" ]; then
                clients="$1"
                shift;
            fi
        ;;
        --threads)
            shift;
            if [ -n "$1" ]; then 
                threads="$1"
                shift;
            fi 
        ;; 
        --storageclass)
            shift; 
            if [ -n "$1" ]; then 
                storageclass="$1"
                shift;
            fi 
        ;;
        --scaling)
            shift;
            if [ -n "$1" ]; then 
                scaling="$1"
                shift;
            fi 
        ;; 
        --)
            break;
        ;;
        *)
            printf "Check options... something is not good\n"
        ;;
    
    esac 
done 

echo $threads
function create_pod {
        oc new-project $namespace 
        oc new-app --template=$template -p VOLUME_CAPACITY=${volsize}Gi -p MEMORY_LIMIT=${memsize} -p STORAGE_CLASS=${storageclass}
        while [ "$(oc get pods | grep -v deploy | awk '{print $3}' | grep -v STATUS)" != "Running" ] ; do 
	        sleep 5
        done 
        sleep 30 
} 

function run_test { 
        POD=$(oc get pods | grep postgresql | grep -v deploy | awk '{print $1}')
        printf "Running test preparation\n"
        oc exec -i $POD -- bash -c "pgbench -i -s $scaling sampledb"

    # run x itterations of test 
	for thread in $(echo ${threads} | sed -e s/,/" "/g); do
		for m in $(seq 1 $iterations); do
            		if [ -n "$resultdir" ]; then
                		oc exec -i $POD -- bash -c "pgbench -c $clients -j $threads -t $transactions sampledb" 2>&1 | tee -a $resultdir/threads_${thread}_pgbench_run.txt 
            		elif [ ! -z "$benchmark_run_dir" ]; then 
                		oc exec -i $POD -- bash -c "pgbench -c $clients -j $threads -t $transactions sampledb" 2>&1 | tee -a $benchmark_run_dir/threads_${thread}_pgbench_run.txt
            		fi 
		done
	done 

	if [ -n "$resultdir" ]; then
		for thread in $(echo ${threads} | sed -e s/,/" "/g); do
			grep "including" $resultdir/threads_${thread}_pgbench_run.txt | cut -d'=' -f2 |cut -d' ' -f2 >> $resultdir/threads_${thread}_including_connections_establishing.txt
		done 
	elif [ ! -z "$benchmark_run_dir" ]; then
		for thread in $(echo ${threads} | sed -e s/,/" "/g); do
			grep "including" $benchmark_run_dir/threads_${thread}_pgbench_run.txt | cut -d'=' -f2 |cut -d' ' -f2 >> $benchmark_run_dir/threads_${thread}_including_connections_establishing.txt
		done 
	fi 
} 

### draw results 

function draw_result {

	if [ -n "$resultdir" ] ; then 
		for thread in $(echo ${threads} | sed -e s/,/" "/g); do
			echo "Thread-${thread}" > $resultdir/results_thread_${thread}.csv 
			cat  $resultdir/threads_${thread}_including_connections_establishing.txt >>  $resultdir/results_thread_${thread}.csv
		done 

		paste -d',' ${resultdir}/results_thread_*  >> ${resultdir}/results_storageclass_${storageclass}_clients_${clients}_transactions_${transactions}_scaling_${scaling}.csv
		curl -o ${resultdir}/drawresults.py https://raw.githubusercontent.com/ekuric/openshift/master/postgresql/drawresults.py

		python ${resultdir}/drawresults.py -r ${resultdir}/results_storageclass_${storageclass}_clients_${clients}_transactions_${transactions}_scaling_${scaling}.csv -i ff -o ${resultdir}/pgbench_results_storageclass_${storageclass}_clients_${clients}_transactions_${transactions}_scaling_${scaling} -t "Clients:${clients} - Transactions:${transactions} - Scaling:${scaling}" -p bars -x "Test iteration" -y "Transactions/Second (tps/sec)" --series=${iterations}

	elif [ ! -z "$benchmark_run_dir" ] ; then 
		for thread in $(echo ${threads} | sed -e s/,/" "/g); do
			echo "Thread-${thread}" > $benchmark_run_dir/results_thread_${thread}.csv
			cat $benchmark_run_dir/threads_${thread}_including_connections_establishing.txt >>  $benchmark_run_dir/results_thread_${thread}.csv
		done 

		paste -d',' $benchmark_run_dir/results_thread_*  >> $benchmark_run_dir/results_storageclass_${storageclass}_clients_${clients}_transactions_${transactions}_scaling_${scaling}.csv
                #curl -o $benchmark_run_dir/drawresults.py https://raw.githubusercontent.com/ekuric/openshift/master/postgresql/drawresults.py

		#python $benchmark_run_dir/drawresults.py -r $benchmark_run_dir/results_storageclass_${storageclass}_clients_${clients}_transactions_${transactions}_scaling_${scaling}.csv -i ff -o $benchmark_run_dir/pgbench_results_storageclass_${storageclass}_clients_${clients}_transactions_${transactions}_scaling_${scaling} -t "Clients:${clients} - Transactions:${transactions} - Scaling:${scaling}" -p bars -x "Test iteration" -y "Transactions/Second (tps/sec)" --series=${iterations}
	fi 

}

function volume_setup {
    # this function will be omitted once storage class params are moved to storageclass 

    CNSPOJECT=$(oc get pods --all-namespaces  | grep glusterfs-storage | awk '{print $1}'  | head -1)
    CNSPOD=$(oc get pods --all-namespaces  | grep glusterfs-storage | awk '{print $2}'  | head -1)
    PV=$(oc get pvc | grep Bound | awk '{print $3}')
    GLUSTERVOLUME=$(oc describe pv $PV | grep vol_  | awk '{print $2}')
    # todo : get some better way to specify these gluster volume parameters 
    
    oc exec -n $CNSPOJECT $CNSPOD -- gluster volume set $GLUSTERVOLUME performance.stat-prefetch off
    oc exec -n $CNSPOJECT $CNSPOD -- gluster volume set $GLUSTERVOLUME performance.write-behind off 
    oc exec -n $CNSPOJECT $CNSPOD -- gluster volume set $GLUSTERVOLUME performance.open-behind off 
    oc exec -n $CNSPOJECT $CNSPOD -- gluster volume set $GLUSTERVOLUME performance.quick-read off 
    oc exec -n $CNSPOJECT $CNSPOD -- gluster volume set $GLUSTERVOLUME performance.strict-o-direct on 
    oc exec -n $CNSPOJECT $CNSPOD -- gluster volume set $GLUSTERVOLUME performance.read-ahead off 
    oc exec -n $CNSPOJECT $CNSPOD -- gluster volume set $GLUSTERVOLUME performance.io-cache off 
    oc exec -n $CNSPOJECT $CNSPOD -- gluster volume set $GLUSTERVOLUME performance.readdir-ahead off
}

function delete_project {
    oc project default 
    oc delete pods -n $namespace --all 
    oc delete pvc -n $namespace --all 
    oc delete project $namespace
    sleep 30
}

# necessary to polish this ... 
case $mode in
    cnsblock)
        create_pod
        run_test 	
    	draw_result
        delete_project
    ;;
    cnsfile)
        create_pod
        volume_setup
        run_test
        draw_result 
        delete_project
    ;;
    otherstorage)
        create_pod
        run_test
        draw_result 
        delete_project
esac 
