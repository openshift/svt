/usr/local/bin/fio --filesize=500M --runtime=120s --ioengine=libaio --direct=1 --time_based --stonewall --filename=/var/lib/fio/testfile \
        --name=sw1m@qd32 --description="Bandwidth via 1MB sequential writes @ qd=32" --iodepth=32 --bs=1m --rw=write \
        --name=sr1m@qd32 --description="Bandwidth via 1MB sequential reads @ qd=32" --iodepth=32 --bs=1m --rw=read \
        --name=rw4k@qd1 --description="e2e latency via 4k random writes @ qd=1" --iodepth=1 --bs=4k --rw=randwrite \
        --name=rr4k@qd1 --description="e2e latency via 4k random reads @ qd=1" --iodepth=1 --bs=4k --rw=randread \
        --name=rw4k@qd32 --description="IOPS via 4k random writes @ qd=32" --iodepth=32 --bs=4k --rw=randwrite \
        --name=rr4k@qd32 --description="IOPS via 4k random reads @ qd=32" --iodepth=32 --bs=4k --rw=randread