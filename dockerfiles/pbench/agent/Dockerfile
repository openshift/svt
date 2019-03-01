#Dockerfile for pbench-agent
FROM centos/tools
MAINTAINER Naga Ravi Chaitanya Elluri <nelluri@redhat.com>

# Setup pbench, sshd install dependencies
RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    curl -s https://copr.fedorainfracloud.org/coprs/ndokos/pbench/repo/epel-7/ndokos-pbench-epel-7.repo > /etc/yum.repos.d/copr-pbench.repo && \
    yum --enablerepo=ndokos-pbench install -y perl-JSON-XS configtools wget openssh-clients pbench-agent iproute sysvinit-tools \
    openssh-server git openssh-server openssh-clients initscripts ansible python-pip which && \
    source /etc/profile.d/pbench-agent.sh && \
    curl -L https://github.com/openshift/origin/releases/download/v1.2.1/openshift-origin-client-tools-v1.2.1-5e723f6-linux-64bit.tar.gz | tar -zx && \
    mv openshift*/oc /usr/local/bin && \
    wget https://dl.google.com/go/go1.11.4.linux-amd64.tar.gz && tar -xzf go1.11.4.linux-amd64.tar.gz && cp go/bin/go /usr/bin/ && mv go /usr/local/ && \
    rm -rf openshift-origin-client-tools-* && \
    mkdir -p /root/.ssh && \ 
    pip install requests && \
    yum clean all && \
    sed -i "s/#Port 22/Port 2022/" /etc/ssh/sshd_config && \
    sed -i "/^#UsePrivilegeSeparation/c UsePrivilegeSeparation no" /etc/ssh/sshd_config && \
    systemctl enable sshd

EXPOSE 2022

# Mount /proc
COPY mount.sh /root/mount.sh
RUN chmod +x /root/mount.sh
COPY pbench.service /etc/systemd/system/pbench.service
RUN systemctl enable pbench.service
RUN mkdir -p /run/systemd/system

ENTRYPOINT ["/usr/sbin/init"]
