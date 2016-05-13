package com.redhat.os.svt.osperf.support.configuration;

/**
 * Application Constants class that has all the global constants for the application.
 * This class can be config for the application giving the ability to customize the 
 * application for the specific needs of the users.
 * 
 * @author schituku
 *
 */
public class AppPerfConfig {
	
	public static final String JMETER_FILES_DIRECTORY = "src/test/jmeter/"; 
	public static final String JMETER_FILES_EXTENSION = "jmx";
	
	public static final String JMETER_TEST_REPORT_DIRECTORY = "target/jmeter/test_report/";
	public static final String JMETER_TEST_REPORT_FILE_EXTENTION = "txt";
	
	public static final String TEST_RESULTS_DIRECTORY = "results";
	
	public static final String AVERAGE_RESPONSE_GRAPH_FILE_NAME ="results/AvgResponseLineChart";
	public static final String PERCENTILE_90_GRAPH_FILE_NAME ="results/percentile90LineChart";
	public static final String GRAPH_FILE_EXTENTION = ".png";
	public static final int    GRAPH_CHART_WIDTH = 640;
	public static final int    GRAPH_CHART_HEIGHT = 480;
	public static final double GRAPH_CHART_SERIES_LINE_THICKNESS = 2.75f;

	public static final String CONSOLIDATED_RESULTS_FILE_NAME ="results/ConsolidatedResults";
	public static final String CONSOLIDATED_RESULTS_FILE_EXTENTION = ".txt";
	public static final String HEADER_USERS = "Users";
	public static final String HEADER_TEST_APP_NAME = "TestAppName";
	public static final String HEADER_TOTAL_HITS = "TotalHits";
	public static final String HEADER_TOTAL_REQUESTS = "TotalRequests";
	public static final String HEADER_ERROR_PERCENTAGE = "Error%";
	public static final String HEADER_AVERAGE_RESPONSE_TIME = "AvgResponseTime(ms)";
	public static final String HEADER_90_PERCENTILE_TIME = "90PercentileTime(ms)";
	public static final String RESULT_FILE_HEADER_FORMAT = "%-10s%-20s%-10s%-15s%-10s%-20s%-20s";
	public static final String RESULT_FILE_LINE_FORMAT = "%-2s%-8s%-22s%-10s%-15s%-10s%-20s%-20s";
}