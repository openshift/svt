# Cluster-Loader config replacer
Replaces parameters in configs used by http, nodevertical and mastervertical tests.

## Run
```
$ python replace.py <test> --config=<path to config> <parameters to be replaced>
```

This tool supports changing the configs of the following tests:
```
- http
- nodevertical
- mastervertical
```

## Available options
The parameters available to be replaced can be found by running the following command:
```
$ python replace.py <test> --help
```
### http
```
usage: replace.py [-h] --config CONFIG [--num NUM] [--run RUN]
                  [--run_time RUN_TIME] [--mb_delay MB_DELAY]
                  [--placement PLACEMENT] [--mb_targets MB_TARGETS]
                  [--mb_conns MB_CONNS] [--mb_ka_requests MB_KA]
                  [--mb_reuse MB_REUSE] [--mb_ramp_up MB_RAMP_UP]
                  [--url_path URL_PATH]

optional arguments:
  -h, --help            show this help message and exit
  --config CONFIG       path to the clusterloader config
  --num NUM             number of projects
  --run RUN             app to execute inside WLG pod
  --run_time RUN_TIME   benchmark run-time in seconds
  --mb_delay MB_DELAY   maximum delay between client requests in ms
  --placement PLACEMENT
                        Placement of the WLG pods based on a node's label
  --mb_targets MB_TARGETS
                        extended RE (egrep) to filter target routes
  --mb_conns MB_CONNS   how many connections per target route
  --mb_ka_requests MB_KA
                        how many HTTP keep-alive requests to send before
                        sending Connection: close
  --mb_reuse MB_REUSE   use TLS session reuse
  --mb_ramp_up MB_RAMP_UP
                        thread ramp-up time in seconds
  --url_path URL_PATH   target path for HTTP(S) requests
```

### nodevertical
```
usage: replace.py [-h] --config CONFIG [--total TOTAL]

optional arguments:
  -h, --help       show this help message and exit
  --config CONFIG  path to the clusterloader config
  --total TOTAL    total number of pods
```

### mastervertical
```
usage: replace.py [-h] --config CONFIG [--num NUM]

optional arguments:
  -h, --help       show this help message and exit
  --config CONFIG  path to the clusterloader config
  --num NUM        number of projects
```
