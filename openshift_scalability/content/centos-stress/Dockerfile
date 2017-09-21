# vim:set ft=dockerfile:
FROM centos:latest

# Install required packages
RUN yum install -y bc gcc git gnuplot go java-1.8.0-openjdk make \
                   openssh-clients patch rsync tar unzip && \
    yum localinstall -y https://dl.fedoraproject.org/pub/epel/6/x86_64/stress-1.0.4-4.el6.x86_64.rpm && \
    mkdir -p build && cd build && \
    git clone https://github.com/openshift/svt.git && \
      cd svt/utils/pctl && go build pctl.go && cp pctl /usr/local/bin && cd ../../.. && \
    git clone -b stable https://github.com/jmencak/mb.git && \
      cd mb && make && cp ./mb /usr/local/bin && cd .. && \
    cd && rm -rf build && \
    yum remove gcc go make patch -y && \
    yum clean all

# Setup jmeter
RUN mkdir -p /opt/jmeter && \
      curl -Ls https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-3.0.tgz \
	| tar xz --strip=1 -C /opt/jmeter && \
        echo "jmeter.save.saveservice.url=true" >> /opt/jmeter/bin/jmeter.properties && \
        echo "jmeter.save.saveservice.thread_counts=true" >> /opt/jmeter/bin/jmeter.properties && \
	echo "jmeter.save.saveservice.autoflush=true" >> /opt/jmeter/bin/user.properties && \
	ln -s /opt/jmeter/bin/jmeter.sh /usr/bin/jmeter && \
      curl -Ls https://jmeter-plugins.org/downloads/file/JMeterPlugins-Standard-1.4.0.zip -O \
               https://jmeter-plugins.org/downloads/file/JMeterPlugins-Extras-1.4.0.zip -O && \
        unzip -n \*.zip -d /opt/jmeter && rm *.zip

WORKDIR /opt/jmeter
COPY root ./

CMD ["./docker-entrypoint.sh"]
