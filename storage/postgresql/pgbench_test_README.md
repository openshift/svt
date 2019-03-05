### pgbench load tool for OCP pods 


[pgbench_test.sh](https://github.com/openshift/svt/blob/master/postgresql/pgbench_test.sh) script can be used for executing pgbench benchmark tool
inside postgresql pod running on top of Kubernetes / OpenShift Container Platform (OCP) when storage can be allocated 
dynamically using storage classes

### Supported options 

pgbench_test.sh supports below options 

``` 
The following options are available:

		-n --namespace - name for new namespace to create pod inside
		-t --transactions - the number pgbench transactions
		 --scaling - pgbench scaling factor
		-e --template -  what template to use
		-v --volsize - size of volume for database
		-m --memsize - size of memory to assign to postgresql pod
		-i --iterations - how many iterations of test to execute
		 --mode - what mode to run: cnsfile or cnsblock, or otherstorage
		-r --resultdir - name of directory where to place pgbench results
		 --clients - number of pgbench clients
		 --threads - number of pgbench threads
		 --storageclass - name of storageclass to use to allocate storage

``` 

### Setup

pgbench_test.sh exepects below to be in place and functioning before executing it

- when executed as standalone script pgbench_test.sh does not require any prerequest 
For this test case, check below hot to run it

- when used as input script for [pbench](https://github.com/distributed-system-analysis/pbench) pbench-user-benchmark script

For pbench test case, it is necessary to have below in order to make it work 

- template which supports dynamic storage provision using storage classes

### Usage:  

- standalone case 

```
./pgbench_test.sh -n <namespace> -t <transactions> -e <template> -v <vgsize> -m <memsize> -i <iterations> --mode <mode> -r resultdir --clients <number of clients> --threads <number of threads> --storageclass <name of storageclass> --scaling <scaling factor> 
```
- as input script for pbench-user-benchmark 

```
# pbench-user-benchmark --config="config_name" -- ./pgbench_test.sh -n <namespace> -t <transactions> -e <template> -v <vgsize> -m <memsize> -i <iterations> --mode <mode> -r resultdir --clients <number of clients> --threads <number of threads> --storageclass <name of storageclass> --scaling <scaling_factor> 
``` 
Where ```mode``` can be either ```cnsblock```, ```cnsfile```, or ```otherstorage```  


- for `cnsblock` case template needs to be configured to use storageclass based on cns block 
- for `cnsfile` case template requirement for template is to use storageclass based on cns file 
- as it can be clear from name, ```otherstorage``` means any other storage configured in storage class section inside template used for postgresql 

Example how to edit PVClaim section in template is showed below 

``` 
        ...
        ....
		"annotations":{
			"volume.beta.kubernetes.io/storage-class": "${STORAGE_CLASS}"	
			}, 
                "name": "${DATABASE_SERVICE_NAME}"
            },
            ....
``` 

add also in ```parameters``` section 

```
	{
	   "description": "Storage class to use",
	   "displayName": "Storage class name",
	   "name": "STORAGE_CLASS",
	   "required": true, 
           "value": "glusterfs-storage-block" 
	}
``` 


Example usage with pbench-user-benchmark 

``` 
# pbench-user-benchmark --config="test_postgresql" -- ./pgbench_test.sh -n pgblock -t 100 -e glusterblock-postgresql-persistent -v 20 -m 2 -i 5 --mode cnsblock --threads 2 --clients 10 --storageclass glusterfs-storage --scaling 10 
``` 

### Todo 

Get support for ```kubectl``` client to be k8s compatible (PR welcome)
