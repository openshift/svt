package com.redhat.os.svt.osperf.tests;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.Test;

import com.redhat.os.svt.osperf.appperf.PerfTestPlanCreator;

public class PrePerfTests {
 
	private final Logger LOG = LoggerFactory.getLogger(PrePerfTests.class);
    
    @Test
    public void testCreatePlan(){
    	LOG.info("Running the pre performance test activities");
    	PerfTestPlanCreator creator = new PerfTestPlanCreator();
    	creator.createTestPlan();
    }
}