#!/usr/bin/env bash
#ELASTICSEARCH_VERSION="${1:-2.3.1}"
#LUCENE_CORE_VERSION="${2:-5.5.0}"
#LUCENE_COMMON_ANALYZERS="${2:-5.5.0}"

ELASTICSEARCH_VERSION="$1"  
LUCENE_CORE_VERSION="$2"
LUCENE_COMMON_ANALYZERS="$2"
MAVEN_CENTRAL_URL="http://central.maven.org/maven2"

echo "[+] "
echo "[+] ELASTICSEARCH_VERSION: $ELASTICSEARCH_VERSION"
echo "[+] LUCENE_CORE_VERSION: $LUCENE_CORE_VERSION"
echo "[+] LUCENE_COMMON_ANALYZERS: $LUCENE_COMMON_ANALYZERS"

wget ${MAVEN_CENTRAL_URL}/org/elasticsearch/elasticsearch/${ELASTICSEARCH_VERSION}/elasticsearch-${ELASTICSEARCH_VERSION}.jar
wget ${MAVEN_CENTRAL_URL}/org/apache/lucene/lucene-core/${LUCENE_CORE_VERSION}/lucene-core-${LUCENE_CORE_VERSION}.jar
wget ${MAVEN_CENTRAL_URL}/org/apache/lucene/lucene-analyzers-common/${LUCENE_COMMON_ANALYZERS}/lucene-analyzers-common-${LUCENE_COMMON_ANALYZERS}.jar


echo "Finished." && exit 0
