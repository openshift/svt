FROM centos

MAINTAINER Vikas Choudhary "vichoudh@redhat.com"

ENV container docker

ARG producer
ARG consumer
ARG stac_url
ARG iface_name=eth0
ARG fast_mode


RUN yum install --assumeyes \
        openssh-clients \
        openssh-server \
	net-tools \
	libevent \
	screen \
	bc \
	sysstat \
	tuna \
	tuned \
	perl \
	ntpdate \
        wget; \
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
    sed -i 's/.*StrictHostKeyChecking.*/StrictHostKeyChecking no/' /etc/ssh/ssh_config; \
    sed -i -- 's/#Port 22/Port 2222/g' /etc/ssh/sshd_config; \
    sed -i 's/.*Port 22/Port 2222/' /etc/ssh/ssh_config; \
    ln -s /usr/lib64/libgmp.so.10 /usr/lib64/libgmp.so.3; \
    echo "root:redhat" | chpasswd

RUN wget ${stac_url}; \
    tar zxf STAC-N-Tools-Pkg20131015_jeder.tar.gz; \
    mv STAC-N-Tools-Pkg20131015 /opt/; \
    #echo -e "set -x\n$(cat /opt/STAC-N-Tools-Pkg20131015/Linux/orchestration-initial-customization/common_tcp.sh)" > /opt/STAC-N-Tools-Pkg20131015/Linux/orchestration-initial-customization/runTest.sh; \
    #echo -e "set -x\n$(cat /opt/STAC-N-Tools-Pkg20131015/Linux/orchestration-initial-customization/common_tcp.sh)" > /opt/STAC-N-Tools-Pkg20131015/Linux/orchestration-initial-customization/common_tcp.sh; \
    sed -i -- "s/ssh/ssh -q/" /opt/STAC-N-Tools-Pkg20131015/Linux/orchestration-initial-customization/runTest.sh; \
    sed -i -- "s/ssh/ssh -q/" /opt/STAC-N-Tools-Pkg20131015/Linux/orchestration-initial-customization/common_tcp.sh; \
    sed -i -- "s/scp/scp -q/" /opt/STAC-N-Tools-Pkg20131015/Linux/orchestration-initial-customization/runTest.sh; \
    sed -i "s/.*RUN_WITH_SCREEN=.*/export RUN_WITH_SCREEN=0/" /opt/STAC-N-Tools-Pkg20131015/Linux/orchestration-initial-customization/run_common.sh; \
    sed -i "s/producer1=.*/producer1=${producer}/" /opt/STAC-N-Tools-Pkg20131015/Linux/orchestration-initial-customization/run_common.sh; \
    sed -i "s/consumer1=.*/consumer1=${consumer}/" /opt/STAC-N-Tools-Pkg20131015/Linux/orchestration-initial-customization/run_common.sh; \
    sed -i -- "s/p1p1/${iface_name}/" /opt/STAC-N-Tools-Pkg20131015/Linux/orchestration-initial-customization/common_tcp.sh; \
    sed -i  "s/ADAPTER_PRODUCER_LISTEN_ADDR=.*/ADAPTER_PRODUCER_LISTEN_ADDR=${producer}/" /opt/STAC-N-Tools-Pkg20131015/Linux/orchestration-initial-customization/common_tcp.sh; \
    sed -i  "s/ADAPTER_CONSUMER_LISTEN_ADDR=.*/ADAPTER_CONSUMER_LISTEN_ADDR=${consumer}/" /opt/STAC-N-Tools-Pkg20131015/Linux/orchestration-initial-customization/common_tcp.sh; \
    sed -i -- "s/orchestrationInterface = em1/orchestrationInterface = ${iface_name}/g" /opt/STAC-N-Tools-Pkg20131015/Linux/config/stac.n.1.cfg; \
    mkdir /usr/lib/tuned/stac

COPY tuned.conf /usr/lib/tuned/stac/tuned.conf
RUN if [ "${fast_mode}" = "True" ]; then sed -i "s/fixedMessageRate=100000/fixedMessageRate=1000;/g" /opt/STAC-N-Tools-Pkg20131015/Linux/config/stac.n.1.cfg; \
    sed -i "s/minMessageRate.*/minMessageRate=2000;/g" /opt/STAC-N-Tools-Pkg20131015/Linux/config/stac.n.1.cfg; \
    sed -i "s/maxMessageRate.*/maxMessageRate=2000;/g" /opt/STAC-N-Tools-Pkg20131015/Linux/config/stac.n.1.cfg; \
    sed -i "s/stepTestDuration.*/stepTestDuration=50;/g" /opt/STAC-N-Tools-Pkg20131015/Linux/config/stac.n.1.cfg; \
    sed -i "s/maxAndFixedTestDuration.*/maxAndFixedTestDuration=50;/g" /opt/STAC-N-Tools-Pkg20131015/Linux/config/stac.n.1.cfg; \
    sed -i "s/saveRate.*/saveRate = 100;/g" /opt/STAC-N-Tools-Pkg20131015/Linux/config/stac.n.1.cfg; \
    sed -i "s/primaryItemCount.*/primaryItemCount = 1000;/g" /opt/STAC-N-Tools-Pkg20131015/Linux/config/stac.n.1.cfg; \
    sed -i "s/uniqueItemCount.*/uniqueItemCount = 1000;/g" /opt/STAC-N-Tools-Pkg20131015/Linux/config/stac.n.1.cfg; \
    sed -i "s/saveOffset.*/saveOffset = 5;/g" /opt/STAC-N-Tools-Pkg20131015/Linux/config/stac.n.1.cfg; fi

VOLUME [ "/sys/fs/cgroup" ]

CMD [ "/usr/sbin/init" ]

