FROM centos/tools

MAINTAINER Siva Reddy "schituku@redhat.com"

ENV container docker

RUN yum install --assumeyes \
    	openssh-clients \
    	openssh-server; \
    yum clean all; \
    (cd /lib/systemd/system/sysinit.target.wants/; \
    for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*; \
    rm -f /etc/systemd/system/*.wants/*; \
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*; \
    rm -f /lib/systemd/system/anaconda.target.wants/*; \
    rm -f /lib/systemd/system/systemd*udev*; \
    rm -f /lib/systemd/system/getty.target; \
    ssh-keygen -A; \
    systemctl enable sshd; \
    echo "root:redhat" | chpasswd

RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm; \
    curl -o /etc/yum.repos.d/pbench.repo https://copr.fedorainfracloud.org/coprs/ndokos/pbench/repo/epel-7/ndokos-pbench-epel-7.repo; \
    yum clean expire-cache; \
    yum install --assumeyes \
        configtools \
	pbench-agent \
	pbench-uperf; \
    yum clean all; \
    source /etc/profile.d/pbench-agent.sh
    
VOLUME [ "/sys/fs/cgroup" ]

CMD ["/usr/sbin/init"]
