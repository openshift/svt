FROM openshift/base-centos7

MAINTAINER Vikas Choudhary "vichoudh@redhat.com"

ENV container docker

ARG github_url_stac_config

RUN git clone ${github_url_stac_config}
RUN wget http://mirror.centos.org/centos/7/updates/x86_64/Packages/kernel-`uname -r`.rpm \
    && wget http://mirror.centos.org/centos/7/updates/x86_64/Packages/kernel-devel-`uname -r`.rpm \
    && yum install -y kernel*.rpm
RUN yum install --assumeyes \
        python-devel \
        libtool \
        libpcap-devel \
        openssh-clients \
        openssh-server \
        net-tools \
        libevent \
        screen \
        bc \
        sysstat \
        rpm-build\
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
    ln -s /usr/lib64/libgmp.so.10 /usr/lib64/libgmp.so.3
COPY  s2i/bin/* /usr/libexec/s2i/
RUN set -x && config_repo=`echo "${github_url_stac_config}" | rev | cut -d / -f 1 | rev`\
    && source ${config_repo%.git*}/stac_config \
    && wget -q ${Onload_tar_url} \
    && onload_tar_file=`echo "$Onload_tar_url" | rev | cut -d / -f 1 | rev` \
    && rpmbuild -tb $onload_tar_file --quiet

