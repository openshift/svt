from websocket import create_connection
from ConfigParser import SafeConfigParser
import ssl
import gevent
import time
import json

                                                                                                                                                               
class Transaction(object):
    def __init__(self, varfile='ose_vars.cfg'):
	'''
	 Gets instantiated once only
	'''

        parser = SafeConfigParser()
        parser.read(varfile)
    
        self.ose_server = parser.get('wss', 'ose_server')
        self.ose_project = parser.get('wss', 'ose_project')
        self.ose_resver = parser.get('wss', 'ose_resver')
        self.ose_token = parser.get('wss', 'ose_token')

        
    def run(self):
        
	'''
	 Each thread runs this method independently
	'''
        
        url = 'wss://{}/api/v1/namespaces/{}/events?watch={}&resourceVersion={}&access_token={}'.format(self.ose_server, self.ose_project, 'true', self.ose_resver, self.ose_token)

        start = time.time()
        # Ignore self signed certificates
        ws = create_connection(url, sslopt={"cert_reqs": ssl.CERT_NONE})
        self.ws = ws

        i = 0
        while i <= 5:
	    res = ws.recv()
	    data = json.loads(res)
            print(data)
            i += 1
            
        ws.close


if __name__ == '__main__':
    trans = Transaction()
    trans.run()
