Analyzer parses the data in the input files to prep them for drawing graphs. 
In the process files are created in the output directory.
   The following files can be analyzed and graphed:
   -- rsyslog cpu or memory 
   -- journald cpu or memory
   -- router total hits
   -- router hits per sec

Input files have to be of the format
     CONDITION_<<MEASURABLE>>.csv
valid measurables (which is case insensitive)  with examples are given below:     
       WITH_MM_1_500_20_CPU.csv
       WITHOUT_MM_1_1000_20_MEMORY.csv
       results-routerperf-total-hits.csv
       results-routerperf-hits-per-sec.csv
       
The results directory will have the graphs drawn on the data in the input files.

Steps to run:
 from osperf-analyser folder run:
mvn test       