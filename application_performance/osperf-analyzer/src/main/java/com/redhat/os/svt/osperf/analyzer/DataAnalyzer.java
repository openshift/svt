package com.redhat.os.svt.osperf.analyzer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class DataAnalyzer {

	private static final Logger LOG = LoggerFactory.getLogger(DataAnalyzer.class);
	public static final String TEST_PLAN_TEMPLATE_FILENAME = "TEST_PLAN_TEMPLATE.jmx";

	public void getDataFiles() {

//		LOG.debug("In Test Plan Create Method");
//		try {
//				ConfigYamlParser parser = new ConfigYamlParser();
//				TestConfig testConfig = parser.parseYaml(TestConfig.TEST_CONFIG_FILE_NAME);
//				List<PerfTestParameter> tests = testConfig.getTestParameters();
//
//				// create or clean the input directory
//				File inputDirectory = new File(AppPerfConfig.TEST_INPUT_FILES_DIRECTORY);
//				if( ! inputDirectory.isDirectory()){
//					FileUtils.forceMkdir(inputDirectory);
//				}else{
//					FileUtils.cleanDirectory(inputDirectory);
//				}
//				
//				for (PerfTestParameter test : tests) {
//					LOG.debug("App URL: {}", test.getAppURL());
//					LOG.debug("The test name: {}", test.getTestSuiteName());
//					
//					//TODO Code for extracting the path from the URL along with domain name and port.
//					String [] appURLContents = test.getAppURL().split("/");
//					String domainName="";
//					String port="";
//					String path= "";
//					
//					if(appURLContents!=null &&  appURLContents.length>2){
//						LOG.debug("The appURLContent[2] : {}",appURLContents[2]);
//						String [] domainString = appURLContents[2].split(":");
//						if(domainString!=null && domainString.length==2){
//							domainName = domainString[0];
//							port = domainString[1];
//							LOG.debug("DomainName: {} Port: {}", domainName, port);
//						}else if(domainString!=null && domainString.length==1){
//							domainName = domainString[0];
//							LOG.debug("DomainName: {} Port: {}", domainName, port);
//						}else if(domainString!=null){
//							//TODO add custom exception to throw for invalid URL.
//							LOG.debug("domainString length: {}", domainString.length);
//						}
//						if(appURLContents.length==4){
//							// path is also present
//							path = appURLContents[3];
//						}
//						LOG.debug("The domain name: {}", domainName);
//						LOG.debug("The port: {}", port);
//						LOG.debug("The path is: {}", path);
//					}else {
//						// TODO add exception custom here 
//					}
//					
//					for (long numOfUsers : test.getNumberOfUsers()) {
//						for (long rampUpTime : test.getRampUpTime()) {
//							for (long numOfUserLoops : test.getNumberOfUserLoops()) {
//								for (long numOfAppLoops : test.getNumberOfAppLoops()) {
//									for (long intervalBetweenAppHits : test.getIntervalBetweenAppHits()) {
//										createOneTestPlan(test.getTestSuiteName(), numOfUsers, 
//												rampUpTime, numOfUserLoops, numOfAppLoops, 
//												domainName, port, path, intervalBetweenAppHits);
//									}
//								}
//							}
//						}
//					}
//					
//
//
//				 }
//			} catch (Exception e) {
//				e.printStackTrace();
//				LOG.debug("EXCEPTION");
//		}

	}

}
