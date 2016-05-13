import time
import argparse
import subprocess
import locust
import pprint
import sys


def parser():
    parser_obj = argparse.ArgumentParser(description="Connects to several OSO console web socket endpoints")
    parser_obj.add_argument('-s', '--server', action="store", dest="server", default='10.1.236.15:8443', required=True)
    parser_obj.add_argument('-p', '--project', action="store", dest="project", default='openshift-infra')
    parser_obj.add_argument('-r', '--resourceversion', action="store", dest="resver", default='0')
    parser_obj.add_argument('-f', '--tokenfile', action="store", dest="tokenfile")
    parser_obj.add_argument('-t', '--token', action="store", dest="token")
    parser_obj.add_argument('-w', '--watch', action="store", dest="watch", default='True')
    return parser_obj


if __name__ == "__main__":
    parser = parser()
    opts = parser.parse_args()

    if not (opts.tokenfile or opts.token):
        parser.error('Need at least one of --token or --tokenfile')

    tokenlist = []
    urllist = []

    events = ('api/v1/namespaces/{}/pods'.format(opts.project),
              'api/v1/namespaces/{}/services'.format(opts.project),
              'api/v1/namespaces/{}/replicationcontrollers'.format(opts.project),
              'oapi/v1/namespaces/{}/builds'.format(opts.project),
              'oapi/v1/namespaces/{}/deploymentconfigs'.format(opts.project),
              'oapi/v1/namespaces/{}/imagestreams'.format(opts.project),
              'oapi/v1/namespaces/{}/routes'.format(opts.project),
              'oapi/v1/namespaces/{}/buildconfigs'.format(opts.project))

    with open(opts.tokenfile) as f:
        for token in f:
            tokenlist.append(token.strip())

    for token in tokenlist:
        print('user token: {}'.format(token))
        for event in events:
            urllist.append('wss://{}/{}?watch={}&resourceVersion={}&access_token={}'.format(
                            opts.server, event, opts.watch, opts.resver, token))

    for url in urllist:
        print("Testing: {}".format(url))
        subprocess.Popen(['wsdump.py', '-vv', '-n', '-r', url])