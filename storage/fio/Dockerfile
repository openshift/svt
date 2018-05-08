FROM registry.access.redhat.com/rhel7/rhel

### make sure you have the following files in the current folder. Otherwise, find them
### https://github.com/openshift/svt/tree/master/image_provisioner/playbooks/roles/repo-install/files
### https://github.com/openshift/aos-ansible/tree/master/playbooks/roles/ops_mirror_bootstrap/files

COPY epel.repo /etc/yum.repos.d/epel.repo
COPY rhel7next.repo /etc/yum.repos.d/rhel7next.repo
COPY client-cert.pem /var/lib/yum/client-cert.pem
COPY client-key.pem /var/lib/yum/client-key.pem
COPY ndokos-pbench-epel-7.repo /etc/yum.repos.d/ndokos-pbench-epel-7.repo
COPY ndokos-pbench-interim.repo /etc/yum.repos.d/ndokos-pbench-interim.repo

RUN echo "root:redhat" | chpasswd; \
    yum clean all; \
    rm -rf /var/cache/yum; \
    yum install -y openssh-server pbench-agent pbench-fio

CMD ["/usr/sbin/init"]