import gevent
import ssl
from websocket import create_connection
from locust import HttpLocust, TaskSet, task, events
import json
import time


class TaskSetAPI(TaskSet):
    """
    events = (
              'api/v1/namespaces/{}/pods'.format(project),
              'api/v1/namespaces/{}/services'.format(project),
              'api/v1/namespaces/{}/replicationcontrollers'.format(project),

              'oapi/v1/namespaces/{}/builds'.format(project),
              'oapi/v1/namespaces/{}/deploymentconfigs'.format(project),
              'oapi/v1/namespaces/{}/imagestreams'.format(project),
              'oapi/v1/namespaces/{}/routes'.format(project),
              'oapi/v1/namespaces/{}/buildconfigs'.format(project)
              )
    """

    @task(1)
    def on_start(self):

        urllist = []
        project = 'webapp1'
        resVersion = 0
        watch='True'
        token = 'pi31Z_9uzN2p0ZAzUt1Sfsmq1lakFrXDnxdJf87Ut_0'
        srv = 'ec2-x-x-x-x.us-west-2.compute.amazonaws.com:8443'

        '''url = 'wss://{}/api/v1/namespaces/{}/events?watch=true&resourceVersion={}&access_token={}'.format(srv,
                                                                                                         project,
                                                                                                         resVersion,
                                                                                                         token)
        '''

        api_ws_urls = (
            'api/v1/namespaces/{}/pods'.format(project),
            'api/v1/namespaces/{}/services'.format(project),
            'api/v1/namespaces/{}/replicationcontrollers'.format(project),

            'oapi/v1/namespaces/{}/builds'.format(project),
            'oapi/v1/namespaces/{}/deploymentconfigs'.format(project),
            'oapi/v1/namespaces/{}/imagestreams'.format(project),
            'oapi/v1/namespaces/{}/routes'.format(project),
            'oapi/v1/namespaces/{}/buildconfigs'.format(project)
        )

        for event in api_ws_urls:
            urllist.append('wss://{}/{}?watch={}&resourceVersion={}&access_token={}'.format(
                srv, event, watch, resVersion, token))

        for url in urllist:
            ws = create_connection(url, sslopt={"cert_reqs": ssl.CERT_NONE})
            self.ws = ws


        def _receive():
            while True:
                res = ws.recv()
                start_at = time.time()
                data = json.loads(res)
                print(res, data)

                end_at = time.time()
                response_time = int((end_at - start_at) * 1000000)
                events.request_success.fire(
                    request_type='WebSocket Received',
                    name='test/wss',
                    response_time=response_time,
                    response_length=len(res),
                )

        gevent.spawn(_receive)


    @task(2)
    def send(self):
        """
         Payload here makes the connection break [broken pipe].
         Real use case should be with:
         oc create -f $payloadfile.{yml,json}

        """
        payload = {
            "apiVersion": "v1",
            "count": 4,
            "firstTimestamp": "2016-03-14T16:35:15.000Z",
            "involvedObject": {
                "apiVersion": "v1",
                "kind": "Build",
                "name": "ruby-hello-world-1-build",
                "namespace": "default",
                "resourceVersion": "3000",
                "uid": "bbfd8973-ea02-11e5-bab8-28d2447dc82b"
            },
            "kind": "Event",
            "lastTimestamp": "2016-03-14T16:35:22.000Z",
            "message": "no nodes available to schedule pods",
            "metadata": {
                "creationTimestamp": "2016-03-14T16:35:15.000Z",
                "deletionTimestamp": "2016-03-14T18:35:22.000Z",
                "name": "ruby-hello-world-1-build.143bc3016cfdd9c0",
                "namespace": "default",
                "resourceVersion": "3027",
                "selfLink": "/api/v1/namespaces/webapp1/events/ruby-hello-world-1-build.143bc3016cfdd9c0",
                "uid": "bbfed6ce-ea02-11e5-bab8-28d2447dc82b"
            },
            "reason": "FailedScheduling",
            "source": {
                "component": "default-scheduler"
            },
            "type": "Warning"
        }

        start_at = time.time()
        body = json.dumps(payload)
        self.ws.send(body)

        events.request_success.fire(
            request_type='WebSocket Sent',
            name='API event',
            response_time=int((time.time() - start_at) * 1000000),
            response_length=len(body),
        )

    def on_quit(self):
        self.ws.close()


class LocustDispatcher(HttpLocust):
    #desthost = 'https://ec2-x-x-x-x.us-west-2.compute.amazonaws.com:8443'

    task_set = TaskSetAPI

    '''
    These are the minimum and maximum time, in ms, that a simulated user will wait between executing each task.
    min_wait and max_wait default to 1000, and therefore a locust will always wait 1 second between each task if
    min_wait and max_wait are not declared.
    '''
    min_wait = 500
    max_wait = 1000
