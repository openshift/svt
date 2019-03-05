### pgbench load tool for OCP pods 


[pgbench_test.sh](https://github.com/ekuric/openshift/blob/master/postgresql/pgbench_test.sh) script can be used for executing pgbench benchmark tool
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

For any specific pgbench parameter - refer to [pgbench man page](https://www.systutorials.com/docs/linux/man/1-pgbench/)

### Setup

pgbench_test.sh exepects below to be in place and functioning before executing it

- when executed as standalone script pgbench_test.sh does not require any prerequest 

For standalone test case, check below how to run it

- when used as input script for [pbench](https://github.com/distributed-system-analysis/pbench) pbench-user-benchmark script

For pbench test case, it is necessary to have below in order to make it work 

- installed and properly setup pbench from [pbench](https://github.com/distributed-system-analysis/pbench)
- template which supports dynamic storage provision using storage classes

### Usage:  

- standalone case 

```
./pgbench_test.sh -n <namespace> -t <transactions> -e <template> -v <vgsize> -m <memsize> -i <iterations> --mode <mode> -r resultdir --clients <number of clients> --threads <number of threads> --storageclass <name of storageclass>
```
Number of threads can be list, for example **--threads=1,2,5,10** will execute test sequentially with different number of threads for pgbench. 

**Important**

**vgsize** will be in **Gi**, eg, specifying **-v 2** will allocate 2Gi for PVC 
**memsize** is in **Mi**, eg, specifying **-m 2048** will allocated 2Gi for memory limits for pod
**resultdir** will be created in **$PWD** 

Exmple usage for this case is 

```
./pgbench_test.sh -n mytest -t 100 -e cns-postgresql-persistent -v 10 -m 2048 -i 2 --clients 10 --threads 10 --storageclass glusterfs-storage-block --mode cnsblock  --scaling 100 -r resultsdirectory 
``` 
It is also possible to run multiple iterations for number of **pgbench** threads, example usage for this case per below 

```
./pgbench_test.sh -n mytest -t 100 -e cns-postgresql-persistent -v 10 -m 2048 -i 2 --clients 10 --threads 10,20,30,40 --storageclass glusterfs-storage-block --mode cnsblock  --scaling 100 -r resultsdirectory 
``` 

Once test is finished, it will write results in **resultdirectory** where is possible to find **csv** file with results and **png** file which draw them all using [drawresults.py](https://raw.githubusercontent.com/ekuric/openshift/master/postgresql/drawresults.py)
This file can be used as input for other approaches to draw results 

**.csv** file will be like 
``` Thread-10,Thread-20,Thread-30,Thread-40
779.783033,845.761088,863.825659,1277.917710
798.060394,822.748672,855.191311,902.224977
804.976040,1163.257353,1184.700774,1246.657400
811.224755,842.565748,884.425879,561.481683
832.003514,839.403621,871.196248,570.666161
816.856654,855.852964,1232.100658,583.815808
813.316926,42.022967,896.805489,580.899895
827.575477,839.521305,891.568349,578.824292
1116.512551,859.840792,1235.193122,574.642960
827.993465,1177.664879,896.483900,698.873556
``` 

Later this **.csv** file can be used to draw results. 

- Second way of running **pgbench_test.sh** is as input script for pbench-user-benchmark 

In this case we can run as shown below - this mode requires installed [pbench](https://github.com/distributed-system-analysis/pbench)

```
# pbench-user-benchmark --config="config_name" -- ./pgbench_test.sh -n <namespace> -t <transactions> -e <template> -v <vgsize> -m <memsize> -i <iterations> --mode <mode> -r resultdir --clients <number of clients> -- threads <number of threads> --storageclass <name of storageclass> 
``` 

Once test if finished results will be stored in **/var/lib/pbench-agent/**

Another important switch to mention is **mode**, and with ```mode``` we define what storage backend to use.
It can be either ```cnsblock```, ```cnsfile```, or ```otherstorage```  


- for `cnsblock` case PVC will be carved using cns block storage class  
- for `cnsfile` case  PVC will be carved using cns file storage class 
- as it can be clear from name, ```otherstorage``` means any other storage configured in storage class section inside template used for postgresql 

**Important:** storageclass and template supporting storageclasses must be configured and exist prior running this test. Current state of 
OCP template examples does not have support for dynamic storage provision and it is necessary to edit template to add support 
for dynamic storage provision. Below is example of changes in **postgresql-persistent** template 

Example how to edit PVClaim section in postgresql-persistent template is showed below 

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
# pbench-user-benchmark --config="test_postgresql" -- ./pgbench_test.sh -n pgblock -t 100 -e glusterblock-postgresql-persistent -v 20 -m 2 -i 5 --mode cnsblock --threads 2 --clients 10 --storageclass glusterfs-storage 
``` 



### Todo 

Get support for ```kubectl``` client to be k8s compatible (PR welcome) - thought this is not hight priority ;) 
