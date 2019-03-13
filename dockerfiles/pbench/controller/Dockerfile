FROM openshift/origin-tests:v4.0

# Dockerfile for pbench-controller
FROM centos/tools
MAINTAINER Naga Ravi Chaitanya Elluri <nelluri@redhat.com>

ENV KUBECONFIG /root/.kube/config

# Setup pbench, sshd, pbench-ansible, svt and install dependencies
RUN yum --skip-broken clean all && rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    curl -s https://copr.fedorainfracloud.org/coprs/ndokos/pbench/repo/epel-7/ndokos-pbench-epel-7.repo > /etc/yum.repos.d/copr-pbench.repo && \
    yum --skip-broken --enablerepo=ndokos-pbench install -y configtools openssh-clients pbench-agent \
    iproute sysvinit-tools pbench-sysstat openssh-server git ansible which bind-utils blktrace ethtool \
    gnuplot golang httpd-tools hwloc iotop iptables-services kernel ltrace  mailx netsniff-ng \
    net-tools ntp ntpdate numactl pciutils jq perf python-docker-py python-flask python-pip python-rbd \
    python2-boto3 powertop psmisc rpm-build screen sos strace tar tcpdump tmux  xauth wget python-boto3 \
    yum-utils rpmdevtools ceph-common glusterfs-fuse iscsi-initiator-utils openssh-server openssh-clients initscripts && \
    yum clean all && \
    source /etc/profile.d/pbench-agent.sh && \
    mkdir -p /root/.go && echo "GOPATH=/root/.go" >> ~/.bashrc && \
    echo "export GOPATH" >> ~/.bashrc && \
    echo "PATH=\$PATH:\$GOPATH/bin" >> ~/.bashrc && \
    source ~/.bashrc && \
    mkdir -p /root/.ssh && \
    curl -L https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz | tar -zx && \
    mv openshift*/oc /usr/local/bin && \
    rm -rf openshift-origin-client-tools-* && \
    git clone https://github.com/distributed-system-analysis/pbench.git /root/pbench && \
    git clone https://github.com/openshift/svt.git /root/svt && \
    git clone https://github.com/chaitanyaenr/scale-cd-jobs.git /root/scale-cd-jobs && \
    wget https://github.com/redhat-performance/pbench-analyzer/releases/download/v0.21-beta/pbcompare -O /usr/local/bin/pbcompare && chmod 0755 /usr/local/bin/pbcompare && \
    wget https://github.com/redhat-performance/pbench-analyzer/releases/download/v0.21-beta/pbscraper -O /usr/local/bin/pbscraper && chmod 0755 /usr/local/bin/pbscraper && \
    mkdir -p /usr/libexec/atomic-openshift && \
    echo "source /opt/pbench-agent/profile" >> ~/.bashrc && source ~/.bashrc && \
    sed -i "s/#Port 22/Port 2022/" /etc/ssh/sshd_config && \
    sed -i "/^#UsePrivilegeSeparation/c UsePrivilegeSeparation no" /etc/ssh/sshd_config && \
    touch /etc/sysconfig/network && \
    systemctl enable sshd

# Expose ports
EXPOSE 2022 9090

# Run pbench as a service
COPY pbench.service /etc/systemd/system/pbench.service
COPY run.sh /root/run.sh
COPY config /root/.ssh/config
RUN chmod 600 /root/.ssh/config
COPY pbench-agent.cfg /opt/pbench-agent/config/pbench-agent.cfg
COPY pbench-agent-default.cfg /opt/pbench-agent/config/pbench-agent-default.cfg
RUN chmod +x /root/run.sh
RUN systemctl enable pbench.service
RUN mkdir -p /run/systemd/system

# Copy the openshift-tests binary from openshift/origin:v4.0 image
COPY --from=0 /bin/openshift-tests /bin/openshift-tests

ENTRYPOINT ["/usr/sbin/init"]
