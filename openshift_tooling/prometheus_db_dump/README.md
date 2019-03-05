# Prometheus DB dump
Script to capture prometheus DB from the running prometheus pods to local file system. This can be used to look at the metrics later by running
prometheus locally with the backed up DB.

## Run
```
$ ./prometheus_dump.sh <output_dir>
```

## Visualize the captured data locally on prometheus server
```
$ ./prometheus_view.sh <db_tarball_url>
```
This installs prometheus server and loads up the DB, the server can be accessed at https://localhost:9090.
