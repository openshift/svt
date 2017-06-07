package com.redhat.os.svt.osperfscale.tests;

import java.io.File;
import java.io.IOException;

import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

import com.redhat.os.svt.osperfscale.ResultProcessor;
import com.redhat.os.svt.osperfscale.common.AppConstants;
import com.redhat.os.svt.osperfscale.utils.GraphCreator3D;

public class PostPerfTests {
	private final Logger LOG = LoggerFactory.getLogger(PostPerfTests.class);
	
	@BeforeClass
	public void oneTimeSetup(){
		//create or clear the graphs folder.
		try {
			File resultsDirectory = new File(AppConstants.GRAPHS_DIRECTORY);
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
    
//	@Test
//	public void testAddHeader(){
//		LOG.info("Running the pre performance test activities");
//		ResultProcessor.addHeaderToResults();
//	}
	
	
//    @Test
//    public void testProcessResults(){
//    	LOG.info("Running the pre performance test activities");
//			ResultProcessor.processResults();
//    }
    
	@Test
	public void createResponseLineGraph(){
		LOG.info("Creating Line Graph for responses ");
		GraphCreator3D creator = new GraphCreator3D();
		creator.createResponseLineChart(ResultProcessor.getResults());
	}
	@Test
	public void createAvgResponseLineGraph(){
		LOG.info("Creating Line Graphs for Average Responses");
		GraphCreator3D creator = new GraphCreator3D();
		creator.createAvgResponseLineChart(ResultProcessor.getResults());
	}
	@Test
	public void create90PercentileLineGraph(){
		LOG.info("Creating Line Graphs for Percentile Responses");
		GraphCreator3D creator = new GraphCreator3D();
		creator.createNinetyPercentileLineChart(ResultProcessor.getResults());
	}
	@Test
	public void createBarGraph(){
		LOG.info("Creating Bar Graphs for Responses");
		GraphCreator3D creator = new GraphCreator3D();
		creator.createResponseBarChart(ResultProcessor.getResults());
	}
}