package com.redhat.os.svt.osperf.analyzer.support.configuration;

import java.util.ArrayList;
import java.util.List;

import com.redhat.os.svt.osperf.analyzer.PerfTestParameter;

public class TestConfig {
	
	public static final String TEST_CONFIG_FILE_NAME = "TestConfig.yaml";
	
	List<PerfTestParameter> testParameters = new ArrayList<PerfTestParameter>();

	public List<PerfTestParameter> getTestParameters() {
		return testParameters;
	}

	public void setTestParameters(List<PerfTestParameter> testParameters) {
		this.testParameters = testParameters;
	}
}