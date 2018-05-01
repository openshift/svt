FROM docker.io/openjdk:8-jdk

ENV ycsb_version=0.12.0

RUN curl -O --location https://github.com/brianfrankcooper/YCSB/releases/download/${ycsb_version}/ycsb-${ycsb_version}.tar.gz

RUN tar xfz ycsb-${ycsb_version}.tar.gz
RUN mv ycsb-${ycsb_version} ycsb

WORKDIR /ycsb

RUN echo "hanging there ..." > fake.log
CMD ["tail", "-f", "fake.log"]
