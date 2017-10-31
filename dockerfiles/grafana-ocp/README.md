# grafana-ocp

This template creates a custom Grafana instance preconfigured to gather Prometheus openshift metrics.
It is uses OAuth token to login openshift Prometheus.

### Pull standalone docker grafana instance
1. ```docker pull docker.io/mrsiano/grafana-ocp```
2. ```docker run -d -ti -p 3000:3000 mrsiano/grafana-ocp "./bin/grafana-server"```

### Build and run the docker image
1. ```docker build -t grafana-ocp .```
2. ```docker run -d -ti -p 3000:3000 grafana-ocp "./bin/grafana-server"```

#### Resources 
- example video https://youtu.be/srCApR_J3Os
- deploy openshift prometheus https://github.com/openshift/origin/tree/master/examples/prometheus 
