FROM docker.io/maven:3.5-jdk-8

ENV activemq_version=5.15.4

WORKDIR /app

RUN svn co http://svn.apache.org/repos/asf/activemq/sandbox/activemq-perftest; \
    cd activemq-perftest/; \
    sed -i -e "s/5.8-SNAPSHOT/${activemq_version}/g" ./pom.xml

RUN echo "hanging there ..." > fake.log
CMD ["tail", "-f", "fake.log"]