# [WIP] placeholder 
FROM 
MAINTAINER 


# Install jmeter


# Wget/Copy dependency lucene and elasticsearch jars
RUN cd ${JMETER_PATH}/lib
./pull_jars.sh ./

# Add ElasticSearchBackendListener
ADD elasticsearch.jar ${JMETER_PATH}/lib/ext/ 

WORKDIR ${JMETER_PATH}
ENTRYPOINT ["./jmeter.sh"]
