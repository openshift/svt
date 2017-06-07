package com.redhat.os.svt.osperfscale.common;

import org.apache.commons.math3.stat.descriptive.DescriptiveStatistics;

public class ResponseObject {
	
	public static short RESPONSE_CODE_200 = 200; 
	
	/**
	 * The http response code received on hit of the url
	 */
	private short httpCode;
	/**
	 * count of the httpCode received during a test
	 */
	private int totalCount;
	/**
	 * The response times of the httpCode 
	 */
	private long responseTime;
	private DescriptiveStatistics responseStats = new DescriptiveStatistics();

}
