#!/usr/bin/env bash
# Purpose:
# Bulk API indexing of large files. e.g.: 20, 50, 80, 100MB
# Those files are too big to be tracked so they won't be uploaded.

host=$1
index1=$2
index2=$3

# hardcode your index mappings below...
# index1
curl -XPUT http://$host:9200/$index1 -d '
{
 "mappings" : {
  "_default_" : {
   "properties" : {
    "speaker" : {"type": "string", "index" : "not_analyzed" },
    "play_name" : {"type": "string", "index" : "not_analyzed" },
    "line_id" : { "type" : "integer" },
    "speech_number" : { "type" : "integer" }
   }
  }
 }
}
';

# hardcode your mappings here...
# index2
curl -XPUT http://$host:9200/$index2-2016.05.18 -d '
{
  "mappings": {
    "log": {
      "properties": {
        "geo": {
          "properties": {
            "coordinates": {
              "type": "geo_point"
            }
          }
        }
      }
    }
  }
}
';

curl -XPUT http://$host:9200/$index2-2016.05.19 -d '
{
  "mappings": {
    "log": {
      "properties": {
        "geo": {
          "properties": {
            "coordinates": {
              "type": "geo_point"
            }
          }
        }
      }
    }
  }
}
';

curl -XPUT http://$host:9200/$index2-2016.05.20 -d '
{
  "mappings": {
    "log": {
      "properties": {
        "geo": {
          "properties": {
            "coordinates": {
              "type": "geo_point"
            }
          }
        }
      }
    }
  }
}
';

# Bulk API indexing of large files.
curl -XPOST "$host:9200/$index1/_bulk?pretty" --data-binary @$index1.json
# default index
curl -XPOST "$host:9200/_bulk?pretty" --data-binary @$index2.jsonl
