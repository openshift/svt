# A set of tools to test secure web sockets implementation in the console.

Uses [Multi-Mechanize](https://multi-mechanize.readthedocs.org/en/latest/)


**Required:**
sudo yum install -y python-devel pyOpenSSL python-websocket-client python-matplotlib
sudo pip install -U multi-mechanize greenlet



**Create a project with:**
multimech-newproject wsstest

**Run with:**
multimech-run wsstest


-----
Notes:
There is a [locustio](http://docs.locust.io/en/latest/quickstart.html) test file under the utils folder.

Required:
sudo pip install locustio

Run with:
srv='https://osemaster:8443'; locust --no-web --host=${srv} -f utils/locustfile.py -c 50 -r 10 -n 30 --only-summary
