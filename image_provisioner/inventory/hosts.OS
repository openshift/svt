# vim:ft=ansible:
[all]
# 127.0.0.1

[all:vars]
# qcow specific
#ansible_ssh_private_key_file= $HOME/.ssh/id_rsa_perf
ansible_ssh_private_key_file=
base_image_url=http://download.url/rhel-guest-image-7.2-20160302.0.x86_64.qcow2
base_image_filename=rhel-guest-image-7.2-20160302.0.x86_64.qcow2
content_mirror=false
# amount of GB to extend root partition by.  default size is 10G so extend that by an additional # gb:
extend_disk_gb=15
rhel_repo_hostname=download.devel.redhat.com
root_password=
# repo install
rhel_int_repo_hostname=
# os kickstart
ssh_repo=
# collectd install
config_type=ose
collectd_interval=10
collectd_status=started
graphite_host=
graphite_prefix=ose
# clone repos
github_token=
# pbench config
pbench_internal_hostname=pbench\..*com$
pbench_alternate_hostname=
internal_server=
# docker config
# sda2 for openstack, sdb/xvdb for ec2
config_repo=
docker_login=no
docker_storage_device=/dev/xvdb
docker_storage_vgname=docker_vg
docker_storage_driver=overlay2
# docker_storage_mount_path should be: "/var/lib/docker" as of BZ 1568450
docker_storage_mount_path=/var/lib/docker
container_root_lv_mount_path=/var/lib/docker
# updates the kernel if set to true
update_kernel=false
# URL to pull the latest kernel
kernel_url=https://example.com
# aos-ansible
aos_ansible_path=/root/aos-ansible
aos_ansible_inventory=/root/aos-ansible/inventory/hosts
# required for authentication for new registry registry.reg-aws.openshift.com:443
registry_name=
registry_username=
registry_password=
puddle_url=
# comment image_version for 'latest'
image_version=v3.3.0.30
# image naming, set qcow_type to atomic for atomic images
qcow_type=rhel
# set openshift_version to the rpm version, sometimes with a trailing -N
openshift_version=3.3.0.30-1
# Set this variable to delete the oldest file when creating a new image.
target_directory=
# set atomic to True for atomic image
atomic=False
# cri-o
crio=False
crio_copy_images=False
crio_registry=registry.access.redhat.com
image_repository=
# multipath-blacklist
multipath_blacklist=False
# pbench scrape binaries
binary_url=https://github.com/redhat-performance/pbench-analyzer/releases/download/v0.1-alpha/
# scale-ci results github token
scale_ci_results_token=
