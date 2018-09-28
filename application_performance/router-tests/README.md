Router tests runs the test and generates the graphs for total hits and hits per sec
  The test will hit the routes with different total number of users generating enough traffic
  to consume 80% of core to which ha proxy process is pegged.
 
 Steps to run
  ./run_route_test.sh
  
  Assumptions:
   the svt repo is checked into /root folder
   pbench agent directory /var/lib/pbench-agent exists
   