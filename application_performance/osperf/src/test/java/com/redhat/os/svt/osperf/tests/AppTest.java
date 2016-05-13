package com.redhat.os.svt.osperf.tests;

import java.io.File;
import java.net.URL;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.Test;

import com.redhat.os.svt.osperf.appperf.PerfReportData;
import com.redhat.os.svt.osperf.appperf.PerfTestParameter;
import com.redhat.os.svt.osperf.appperf.PerfTestPlanCreator;
import com.redhat.os.svt.osperf.support.configuration.ConfigYamlParser;
import com.redhat.os.svt.osperf.support.configuration.AppPerfConfig;
import com.redhat.os.svt.osperf.support.configuration.TestConfig;
import com.redhat.os.svt.osperf.support.helper.PerfTestResultParser;

public class AppTest {
 
	private final Logger log = LoggerFactory.getLogger(AppTest.class);
	
//    @Test
    public void testParser() {
         
    	 log.debug("Testing the parser");
    	 try {
	         ConfigYamlParser parser = new ConfigYamlParser();       
			 TestConfig testConfig = parser.parseYaml(TestConfig.TEST_CONFIG_FILE_NAME);
			 List<PerfTestParameter> tests = testConfig.getJmeterTestParameters();
				
			for (PerfTestParameter test : tests) {
				log.debug("App URL: {}", test.getAppURL());
				log.debug("Test Suite Name: {}", test.getTestSuiteName());
				
				for (long user : test.getNumberOfUsers()) {
					log.debug("the user is: {}",user);
				}
				
				for (long rampUpTime : test.getRampUpTime()) {
					log.debug("the ramp up time: {}",rampUpTime);
				}
				for (long numOfUserLoops : test.getNumberOfUserLoops()) {
					log.debug("the User loops: {}",numOfUserLoops);
				}
				for (long numOfAppLoops : test.getNumberOfAppLoops()) {
					log.debug("the app loop: {}",numOfAppLoops);
				}
				for (long interval : test.getIntervalBetweenAppHits()) {
					log.debug("the interval: {}",interval);
				}
				
			}
			
			URL url = Thread.currentThread().getContextClassLoader().getResource(AppPerfConfig.JMETER_FILES_DIRECTORY);
	    	if( url == null ){
	    	    log.debug( "Cannot find resource on classpath");
	    	} else{
	    		log.debug("the directory of the file is: {}", new File(url.getPath()).getParent());
	    	}
	    	
			
			log.debug("the directory of the file is: {}", new File("somefile").getPath());
			log.debug("the directory of the file is: {}", new File("src/test/jmeter").getAbsolutePath());
			
		} catch (Exception e) {
			e.printStackTrace();
			log.debug("EXCEPTION");
		}
    }
    
    @Test
    public void testCreatePlan(){

    	PerfTestPlanCreator creator = new PerfTestPlanCreator();
    	creator.createTestPlan();
    }
    
//    @Test
    public void testReportData(){
    	log.debug("in the report data test");
       
       List<PerfReportData> reportData = PerfTestResultParser.getReportData();
       
       for (PerfReportData jmeterReportData : reportData) {
    	   log.debug(jmeterReportData.getTestPlanName());	
       }
    }
}