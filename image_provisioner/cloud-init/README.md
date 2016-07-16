cloud-init based images require injection of basic credentials.  Point virt-install or OpenStack to this ISO when booting.

For example:
export NAME=packer ; virt-install --import --name $NAME --ram 4096 --vcpus 4 --disk path=/storage/images/$NAME.qcow2 --disk path=/storage/images/cidata.iso,device=cdrom --network bridge=br0 --graphics vnc --check path_in_use=off --noautoconsole
