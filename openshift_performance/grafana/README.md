# Pre-requesits:
```
pip install grafyaml
```
# How to:
modifiy the openshift-dashboard.yaml if needed.
push it to grafana `grafana-dashboard --grafana-url http://{{grafana_host}}:{{grafana_port}} --grafana-apikey {{grafana_apikey}} openshift-dashboard.yaml`
