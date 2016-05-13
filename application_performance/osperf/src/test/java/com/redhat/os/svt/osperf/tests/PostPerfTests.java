package com.redhat.os.svt.osperf.tests;

import java.io.File;
import java.io.IOException;

import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

import com.redhat.os.svt.osperf.support.charts.GraphCreator3D;
import com.redhat.os.svt.osperf.support.configuration.AppPerfConfig;
import com.redhat.os.svt.osperf.support.helper.PerfTestResultWriter;

public class PostPerfTests {
	
	private final Logger LOG = LoggerFactory.getLogger(PostPerfTests.class);
	
	@BeforeClass
	public void oneTimeSetup(){
		//create or clear the results folder.
		try {
			File resultsDirectory = new File(AppPerfConfig.TEST_RESULTS_DIRECTORY);
			if( ! resultsDirectory.isDirectory()){
				FileUtils.forceMkdir(resultsDirectory);
			}else{
				FileUtils.cleanDirectory(resultsDirectory);
			}
		} catch (IOException e) {
			e.printStackTrace();
			LOG.debug("Error cleaning the results directory");
		}
	}
	
	@Test
	public void createGraphImage(){
		LOG.info("Creating Graphs for all the Tests");
//		GraphCreator creator = new GraphCreator();
		GraphCreator3D creator = new GraphCreator3D();
		creator.createMultipleLineChart();
	}
	
	@Test
	public void writeResultsToFile(){
		LOG.info("Writing the consolidated test results into a txt file");
		
		PerfTestResultWriter writer = new PerfTestResultWriter();
		writer.writeTestResultsToFile();
	}
}
