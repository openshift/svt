package com.redhat.os.svt.osperf.support.configuration;

import java.util.ArrayList;
import java.util.List;

import com.redhat.os.svt.osperf.appperf.PerfTestParameter;

public class TestConfig {
	
	public static final String TEST_CONFIG_FILE_NAME = "JmeterTestConfig.yaml";
	
	List<PerfTestParameter> jmeterTestParameters = new ArrayList<PerfTestParameter>();

	public List<PerfTestParameter> getJmeterTestParameters() {
		return jmeterTestParameters;
	}

	public void setJmeterTestParameters(List<PerfTestParameter> jmeterTestParameters) {
		this.jmeterTestParameters = jmeterTestParameters;
	}
}