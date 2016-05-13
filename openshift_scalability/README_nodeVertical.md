nodeVertical.sh script will create N pods across N nodes.

Note:  ensure aos-ansible is run prior to this test

Usage:

On Master node:
# pbench-user-benchmark -C ose-3.1.1.908 -- ./nodeVertical.sh ose-3.1.1.908
# pbench-copy-results

Results will be copied to http://example.com/results
Resource usage on master and node should be measured and compared against previous runs to provide a pass/fail result from Jenkins.
Graphs should be created that plot results against each other.
