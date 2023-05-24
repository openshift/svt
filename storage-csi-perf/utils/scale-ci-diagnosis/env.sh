#!/bin/bash

export OUTPUT_DIR=$PWD
export PROMETHEUS_CAPTURE=true                          # Captures prometheus database when enabled
export PROMETHEUS_CAPTURE_TYPE=full                     # Options available: 'wal' or 'full', wal captures the write ahead log while full captures the entire prometheus DB
export OPENSHIFT_MUST_GATHER=true                       # Captures must-gather when enabled
export STORAGE_MODE=                                    # Option available: 'snappy', Stores the tar ball on the local filesystem when empty, 
