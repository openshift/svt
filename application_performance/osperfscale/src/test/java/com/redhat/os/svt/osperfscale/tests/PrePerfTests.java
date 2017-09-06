package com.redhat.os.svt.osperfscale.tests;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.Test;

import com.redhat.os.svt.osperfscale.RequestCreator;

public class PrePerfTests {
 
	private final Logger LOG = LoggerFactory.getLogger(PrePerfTests.class);

    
    @Test
    public void testCreateRequests(){
    	LOG.info("Running the pre performance test activities: creating request");
    	RequestCreator creator = new RequestCreator();
    	creator.createRequest();
    }

}