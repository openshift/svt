#!/usr/bin/env python
import yaml, sys, argparse

def help():
    print "Following options are available: http, nodevert, mastervert"
    print "Run python config.py <test> --help to look at the options available"

test_name = sys.argv[1]
parser = argparse.ArgumentParser()

# http
if test_name == "http":
    parser.add_argument('--config', required=True, dest="config", help="path to the clusterloader config")
    parser.add_argument('--num', required=False, dest="num", help="number of projects")
    parser.add_argument('--run', required=False, dest="run", help="app to execute inside WLG pod")
    parser.add_argument('--run_time', required=False, dest="run_time", help="benchmark run-time in seconds")
    parser.add_argument('--mb_delay', required=False, dest="mb_delay", help="maximum delay between client requests in ms")
    parser.add_argument('--placement', required=False, dest="placement", help="Placement of the WLG pods based on a node's label")
    parser.add_argument('--mb_targets', required=False, dest="mb_targets", help="extended RE (egrep) to filter target routes")
    parser.add_argument('--mb_conns', required=False, dest="mb_conns", help="how many connections per target route")
    parser.add_argument('--mb_ka_requests', required=False, dest="mb_ka", help="how many HTTP keep-alive requests to send before sending Connection: close")
    parser.add_argument('--mb_reuse', required=False, dest="mb_reuse", help="use TLS session reuse")
    parser.add_argument('--mb_ramp_up', required=False, dest="mb_ramp_up", help="thread ramp-up time in seconds")
    parser.add_argument('--url_path', required=False, dest="url_path", help="target path for HTTP(S) requests")
# nodevertical
elif test_name == "nodevertical":
    parser.add_argument('--config', required=True, dest="config", help="path to the clusterloader config")
    parser.add_argument('--total', required=False, dest="total", help="total number of pods")
# mastervertical
elif test_name == "mastervertical":
    parser.add_argument('--config', required=True, dest="config", help="path to the clusterloader config")
    parser.add_argument('--num', required=False, dest="num", help="number of projects")
else:
    help()
    sys.exit(1)

args = parser.parse_args(sys.argv[2:])

with open(args.config, 'r') as ymlfile:
    cfg = yaml.load(ymlfile)
    if test_name == "http":
        parameters = cfg['projects'][0]['templates'][0]
        if args.num is not None:
            parameters['num'] = args.num
        for param in parameters['parameters']:
            for key, value in param.iteritems():
                if args.mb_delay is not None and key == "MB_DELAY":
                    param[key] = args.mb_delay
                if args.run is not None and key == "RUN":
                    param[key] = args.run
                if args.run_time is not None and key == "RUN_TIME":
                    param[key] = args.run_time
                if args.placement is not None and key == "PLACEMENT":
                    param[key]= args.placement
                if args.mb_targets is not None and key == "MB_TARGET":
                    param[key] = args.mb_targets
                if args.mb_conns is not None and key == "MB_CONNS_PER_TARGET":
                    param[key] = args.mb_conns
                if args.mb_ka is not None and key == "MB_KA_REQUESTS":
                    param[key] = args.mb_ka
                if args.mb_reuse is not None and key == "MB_TLS_SESSION_REUSE":
                    param[key] = args.mb_reuse
                if args.mb_ramp_up is not None and key == "MB_RAMP_UP":
                    param[key] = args.mb_ramp_up
    elif test_name == "nodevert":
        if args.total is not None:
            cfg['projects'][0]['pods'][0]['total'] = args.total
    elif test_name == "mastervert":
        if args.num is not None:
            cfg['projects'][0]['num'] = args.num
    else:
        help()

with open(args.config, 'w') as ymlfile:
    yaml.dump(cfg, ymlfile)
