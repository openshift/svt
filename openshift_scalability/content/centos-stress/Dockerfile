# vim:set ft=dockerfile:
FROM centos:7

### Setup user for build execution and application runtime
ENV APP_ROOT=/opt/stress
ENV PATH=${APP_ROOT}/bin:${PATH} HOME=${APP_ROOT}
WORKDIR ${APP_ROOT}
COPY root ./

### Install required packages
RUN yum -y --setopt=tsflags=nodocs install automake autotools bc epel-release \
        gcc git gnuplot java-1.8.0-openjdk libtool make openssh-clients \
        patch rsync tar unzip && \
    yum -y --setopt=tsflags=nodocs install go stress && \
    mkdir -p build && cd build && \
    git clone https://github.com/openshift/svt.git && \
      cd svt/utils/pctl && go build pctl.go && cp pctl /usr/local/bin && cd ../../.. && \
    git clone -b stable https://github.com/jmencak/mb.git && \
      cd mb && make && cp ./mb /usr/local/bin && cd .. && \
    cd && rm -rf build && \
    yum remove automake autotools gcc go libtool make patch -y && \
    yum clean all

### Setup JMeter
RUN mkdir -p ${APP_ROOT} && \
    curl -Ls https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-3.0.tgz \
      | tar xz --strip=1 -C ${APP_ROOT} && \
    echo "jmeter.save.saveservice.url=true" >> ${APP_ROOT}/bin/jmeter.properties && \
    echo "jmeter.save.saveservice.thread_counts=true" >> ${APP_ROOT}/bin/jmeter.properties && \
    echo "jmeter.save.saveservice.autoflush=true" >> ${APP_ROOT}/bin/user.properties && \
    curl -Ls https://jmeter-plugins.org/downloads/file/JMeterPlugins-Standard-1.4.0.zip -O \
             https://jmeter-plugins.org/downloads/file/JMeterPlugins-Extras-1.4.0.zip -O && \
    unzip -n \*.zip -d ${APP_ROOT} && rm *.zip

### User name recognition at runtime with an arbitrary uid (OpenShift deployments)
RUN chmod -R u+x ${APP_ROOT}/bin && \
    chgrp -R 0 ${APP_ROOT} && \
    chmod -R g=u ${APP_ROOT} /etc/passwd
ENTRYPOINT [ "uid_entrypoint" ]

### Provide defaults for an executing container
CMD run
