package com.redhat.os.svt.osperf.appperf;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.List;

import org.apache.commons.io.Charsets;
import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.redhat.os.svt.osperf.support.configuration.ConfigYamlParser;
import com.redhat.os.svt.osperf.support.configuration.AppPerfConfig;
import com.redhat.os.svt.osperf.support.configuration.TestConfig;

public class PerfTestPlanCreator {

	private static final Logger LOG = LoggerFactory.getLogger(PerfTestPlanCreator.class);
	public static final String TEST_PLAN_TEMPLATE_FILENAME = "TEST_PLAN_TEMPLATE.jmx";
	public static final String SEPERATOR_IN_TEST_PLAN_NAME = "-";
	public static final String TEST_PLAN_TEMPLATE = "TEST_PLAN_TEMPLATE";
	public static final String TEST_SCENARIO_TEMPLATE = "TEST_SCENARIO_TEMPLATE";
	public static final String USERS = "USERS";
	public static final String RAMP_UP_TIME = "RAMP_UP_TIME";
	public static final String NUM_OF_SCENARIO_PASSES = "NUM_OF_SCENARIO_PASSES";
	public static final String NUM_OF_HITS_PER_USER = "NUM_OF_HITS_PER_USER";
	public static final String APP_URL = "APP_URL";
	public static final String PORT = "PORT";
	public static final String PATH_TO_RESOURCE = "PATH_TO_RESOURCE";
	public static final String RESPONSE_CODE_VALUE_TEXT = "RESPONSE_CODE_VALUE";
	public static final String RESPONSE_CODE_VALUE = "200";
	public static final String INTERVAL_BETWEEN_REQUESTS = "INTERVAL_BETWEEN_REQUESTS";
	public static final String TEST_PLAN_NAMING_CONVENTION = 
			"PLANNAME-NUM_OF_USERS-NUM_OF_USER_LOOPS-RAMP_UP_TIME-NUM_OF_APP_LOOPS-INTERVAL_BETWEEN_HITS-";

	public void createTestPlan() {

		LOG.debug("In Test Plan Create Method");
		try {
				ConfigYamlParser parser = new ConfigYamlParser();
				TestConfig testConfig = parser.parseYaml(TestConfig.TEST_CONFIG_FILE_NAME);
				List<PerfTestParameter> tests = testConfig.getJmeterTestParameters();

				// create or clean the Jmeter Directory
				File jmeterDirectory = new File(AppPerfConfig.JMETER_FILES_DIRECTORY);
				if( ! jmeterDirectory.isDirectory()){
					FileUtils.forceMkdir(jmeterDirectory);
				}else{
					FileUtils.cleanDirectory(jmeterDirectory);
				}
				
				for (PerfTestParameter test : tests) {
					LOG.debug("App URL: {}", test.getAppURL());
					LOG.debug("The test name: {}", test.getTestSuiteName());
					
					//TODO Code for extracting the path from the URL along with domain name and port.
					String [] appURLContents = test.getAppURL().split("/");
					String domainName="";
					String port="";
					String path= "";
					
					if(appURLContents!=null &&  appURLContents.length>2){
						LOG.debug("The appURLContent[2] : {}",appURLContents[2]);
						String [] domainString = appURLContents[2].split(":");
						if(domainString!=null && domainString.length==2){
							domainName = domainString[0];
							port = domainString[1];
							LOG.debug("DomainName: {} Port: {}", domainName, port);
						}else if(domainString!=null && domainString.length==1){
							domainName = domainString[0];
							LOG.debug("DomainName: {} Port: {}", domainName, port);
						}else if(domainString!=null){
							//TODO add custom exception to throw for invalid URL.
							LOG.debug("domainString length: {}", domainString.length);
						}
						if(appURLContents.length==4){
							// path is also present
							path = appURLContents[3];
						}
						LOG.debug("The domain name: {}", domainName);
						LOG.debug("The port: {}", port);
						LOG.debug("The path is: {}", path);
					}else {
						// TODO add exception custom here 
					}
					
					for (long numOfUsers : test.getNumberOfUsers()) {
						for (long rampUpTime : test.getRampUpTime()) {
							for (long numOfUserLoops : test.getNumberOfUserLoops()) {
								for (long numOfAppLoops : test.getNumberOfAppLoops()) {
									for (long intervalBetweenAppHits : test.getIntervalBetweenAppHits()) {
										createOneTestPlan(test.getTestSuiteName(), numOfUsers, 
												rampUpTime, numOfUserLoops, numOfAppLoops, 
												domainName, port, path, intervalBetweenAppHits);
									}
								}
							}
						}
					}
					


				 }
			} catch (Exception e) {
				e.printStackTrace();
				LOG.debug("EXCEPTION");
		}

	}
	
	private void createOneTestPlan(String testSuiteName, long numOfUsers, long rampUpTime,
										long numOfUserLoops, long numOfAppLoops, String domainName, 
										String port, String path, long intervalBetweenAppHits)
											throws IOException{
		
		// PLANNAME-NUM_OF_USERS-NUM_OF_USER_LOOPS-RAMP_UP_TIME-NUM_OF_APP_LOOPS-INTERVAL_BETWEEN_HITS 
		String testPlanName = testSuiteName 		+SEPERATOR_IN_TEST_PLAN_NAME+
							  numOfUsers    		+SEPERATOR_IN_TEST_PLAN_NAME+
							  numOfUserLoops		+SEPERATOR_IN_TEST_PLAN_NAME+
							  rampUpTime    		+SEPERATOR_IN_TEST_PLAN_NAME+
							  numOfAppLoops 		+SEPERATOR_IN_TEST_PLAN_NAME+
							  intervalBetweenAppHits+SEPERATOR_IN_TEST_PLAN_NAME;
		
		LOG.debug("Creating test plan: {}",testPlanName);
		
		// create new file in the template directory
		File testPlanFile = new File(AppPerfConfig.JMETER_FILES_DIRECTORY + testPlanName + "." 
									+ AppPerfConfig.JMETER_FILES_EXTENSION );
		
		BufferedReader templateFileStream = new BufferedReader( 
				new InputStreamReader(Thread.currentThread().getContextClassLoader().getResourceAsStream(TEST_PLAN_TEMPLATE_FILENAME)));
		String currentLine;
		while((currentLine = templateFileStream.readLine()) != null){
			if(currentLine.contains(TEST_PLAN_TEMPLATE)){
				currentLine = currentLine.replaceAll(TEST_PLAN_TEMPLATE, testPlanName+"-TestPlan");
			}else if(currentLine.contains(TEST_SCENARIO_TEMPLATE)){
				currentLine = currentLine.replaceAll(TEST_SCENARIO_TEMPLATE, testPlanName+"-TestScenario");
			}else if(currentLine.contains(USERS)){
				currentLine = currentLine.replaceAll(USERS, new Long(numOfUsers).toString());
			}else if(currentLine.contains(RAMP_UP_TIME)){
				currentLine = currentLine.replaceAll(RAMP_UP_TIME, new Long(rampUpTime).toString());
			}else if(currentLine.contains(NUM_OF_SCENARIO_PASSES)){
				currentLine = currentLine.replaceAll(NUM_OF_SCENARIO_PASSES, new Long(numOfUserLoops).toString());
			}else if(currentLine.contains(NUM_OF_HITS_PER_USER)){
				currentLine = currentLine.replaceAll(NUM_OF_HITS_PER_USER, new Long(numOfAppLoops).toString());
			}else if(currentLine.contains(APP_URL)){
				currentLine = currentLine.replaceAll(APP_URL, domainName);
			}else if(currentLine.contains(PORT)){
				currentLine = currentLine.replaceAll(PORT, port);
			}else if(currentLine.contains(PATH_TO_RESOURCE)){
//				currentLine = currentLine.replaceAll(PATH_TO_RESOURCE, "/");
				currentLine = currentLine.replaceAll(PATH_TO_RESOURCE, "/"+path);
			}else if(currentLine.contains(RESPONSE_CODE_VALUE_TEXT)){
				currentLine = currentLine.replaceAll(RESPONSE_CODE_VALUE_TEXT, RESPONSE_CODE_VALUE);
			}else if(currentLine.contains(INTERVAL_BETWEEN_REQUESTS)){
				currentLine = currentLine.replaceAll(INTERVAL_BETWEEN_REQUESTS, new Long(intervalBetweenAppHits).toString());
			}
			
			FileUtils.write(testPlanFile, currentLine, Charsets.UTF_8, true);
		}
		templateFileStream.close();
	}
}
