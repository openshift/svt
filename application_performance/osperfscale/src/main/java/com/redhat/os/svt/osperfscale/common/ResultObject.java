package com.redhat.os.svt.osperfscale.common;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.math3.stat.descriptive.DescriptiveStatistics;

public class ResultObject {

	private String testName;
	/**
	 * the url the is being hit.
	 */
	private String url;
	/**
	 * response time for ok results
	 */
	private List<Long> responseTimes=new ArrayList<Long>();
	
	private DescriptiveStatistics responseStats = new DescriptiveStatistics();
	
	public String getUrl() {
		return url;
	}
	public void setUrl(String url) {
		this.url = url;
	}
	public List<Long> getResponseTimes() {
		return responseTimes;
	}
	public void setResponseTimes(List<Long> responseTimes) {
		this.responseTimes = responseTimes;
	}
	public DescriptiveStatistics getResponseStats() {
		return responseStats;
	}
	public void setResponseStats(DescriptiveStatistics responseStats) {
		this.responseStats = responseStats;
	}
	public String getTestName() {
		return testName;
	}
	public void setTestName(String testName) {
		this.testName = testName;
	}
	
}