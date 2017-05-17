package com.redhat.os.svt.osperfscale.tests;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.Test;

import com.redhat.os.svt.osperfscale.ResultProcessor;

public class PrePerfTests {
 
	private final Logger LOG = LoggerFactory.getLogger(PrePerfTests.class);
    
    @Test
    public void testProcessResults(){
    	LOG.info("Running the pre performance test activities");
			ResultProcessor.processResults();
    }
}