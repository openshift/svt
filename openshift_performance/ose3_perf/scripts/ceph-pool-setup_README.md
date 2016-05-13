## ceph-pool-setup.sh README

### Purpose 
ceph-pool-setup.sh script can be used to setup ceph pool of desired replica size and desired number of images on top of 
rbd device 

### Usage 

./ceph-pool-setup.sh -a [create|delete] -p [ceph pool name] -i [number of rbd images to create] -r [ceph pool replica] -s [size of ceph rbd images [MB] ] 
 
- -a action: what to do it can be c|create - create the ceph pool, or d|delete - delete the ceph pool
- -p pname : ceph pool name
- -i inum : how many images to create on top of pool
- -r replica: ceph pool replica mode - if not specified default replica=3 for ceph pool will be used
- -s -isize: image size - the value is in MB

When invoked with

./ceph-pool-setup.sh -a d -p [poolname] 

ceph pool will be deleted. Use carefully -d option and specify correct pool name to be deleted 



