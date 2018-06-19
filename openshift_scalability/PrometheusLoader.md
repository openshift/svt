# Intro
This tool is used to fire prometheus queries against a prometheus instance in OpenShift.

It also helps to simulate Grafana workloads on a staging cluster.

The app uses a query file which includes a collection of prometheus queries,
the collection fits only to OpenShift deployment.

# How to
python prometheus-loader.py -f <query_file> -i <interval> -t <concurrency> -p <graph_period>  > /dev/null 2>&1 &

interval = bulk frequency, how often queries were being fired (in seconds).
concurrency = how many queries will work in parallel (0-100).
period = for what time period \ data size (in minuets).
