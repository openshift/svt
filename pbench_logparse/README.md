# pbench_logparse

This golang tool was created to parse the output of time series data created by [pbench](https://github.com/distributed-system-analysis/pbench) in CSV format.

```
Usage of ./pbench_logparse:
  -blkdev value
        List of block devices
  -i string
        pbench run result directory to parse (default "/var/lib/pbench-agent/benchmark_result/tools-default/")
  -netdev value
        List of network devices
  -o string
        output directory for parsed CSV result data (default "/tmp/")
  -proc string
        list of processes to gather (default "openshift_start_master_api,openshift_start_master_controll,openshift_start_node,/etcd")
```

Example command:
```
./pbench_logparse ~/work/pbench-result/tools-default/ -o ~/data/ -blkdev vda-write -blkdev xvdb -netdev eth0-rx -netdev eth0-tx
```

`blkdev` represents a single block device name, to add more than one block device, you will need to pass the flag again per device, as above

`i` is the input directory, it must point to the parent of the host data, which is `.../tools-default/`

`o` is the output directory, it can be any directory that includes a trailing slash (dirname/)

`netdev` represents a single network device name, to add more than more network device, you will need to pass the flag again per device, as above

`proc` is a comma-separated list of process names to extract results for, avoid spaces
