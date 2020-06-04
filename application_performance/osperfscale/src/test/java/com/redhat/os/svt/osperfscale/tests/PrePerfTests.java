package com.redhat.os.svt.osperfscale.tests;

import com.redhat.os.svt.osperfscale.common.AppConstants;
import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

import com.redhat.os.svt.osperfscale.RequestCreator;

import java.io.File;
import java.io.IOException;

public class PrePerfTests {
 
	private final Logger LOG = LoggerFactory.getLogger(PrePerfTests.class);

	@BeforeClass(enabled = true)
	public void oneTimeSetup() {
		// create or clear the results folder.
		try {
			File resultsDirectory = new File(AppConstants.TEST_RESULTS_DIRECTORY);
			if (!resultsDirectory.isDirectory()) {
				FileUtils.forceMkdir(resultsDirectory);
			} else {
				FileUtils.cleanDirectory(resultsDirectory);
			}
		} catch (IOException e) {
			e.printStackTrace();
			LOG.debug("Error cleaning the results directory");
		}
	}

    
    @Test
    public void testCreateRequests(){
    	LOG.info("Running the pre performance test activities: creating request");
    	RequestCreator creator = new RequestCreator();
    	creator.createRequest();
    }

}