package com.redhat.os.svt.osperf.analyzer.support.configuration;

import java.util.HashMap;
import java.util.Map;

/**
 * Application Constants class that has all the global constants for the application.
 * This class can be config for the application giving the ability to customize the 
 * application for the specific needs of the users.
 * 
 * @author schituku
 *
 */
public class AppPerfConfig {
	
	public static final String PROCESS_RSYSLOGD = "rsyslogd";
	public static final String PROCESS_JOURNALD = "journald";
	public static final String PROCESS_ROUTER_PERF = "routerperf";
	public static final String MEASURABLE_CPU = "cpu";
	public static final String MEASURABLE_MEMORY = "memory";
	public static final String MEASURABLE_TOTAL_HITS = "total-hits";
	public static final String MEASURABLE_HITS_PER_SEC = "hits-per-sec";
	public static final String USERS = "users";
	
	
	public static final String TEST_INPUT_FILES_DIRECTORY = "input/";
	public static final String TEST_OUTPUT_FILES_DIRECTORY = "output/";
	public static final String TEST_RESULTS_DIRECTORY = "results";
	public static final String CSV_FILES_EXTENSION = "csv";
	
	public static final Map<String, String> GRAPH_X_AXIS_TITLE = new HashMap<String, String>();
    static {
    	GRAPH_X_AXIS_TITLE.put(PROCESS_JOURNALD, "Time Units");
    	GRAPH_X_AXIS_TITLE.put(PROCESS_RSYSLOGD, "Time Units");
    	GRAPH_X_AXIS_TITLE.put(PROCESS_ROUTER_PERF, "Users");
    }
	
	public static final String BASE_GRAPH_FILE_NAME ="results/LineChart";
	public static final String GRAPH_FILE_EXTENTION = ".png";
	public static final int    GRAPH_CHART_WIDTH = 640;
	public static final int    GRAPH_CHART_HEIGHT = 480;
	public static final double GRAPH_CHART_SERIES_LINE_THICKNESS = 2.75f;

	public static final String CONSOLIDATED_RESULTS_FILE_NAME ="results/ConsolidatedResults";
	public static final String CONSOLIDATED_RESULTS_FILE_EXTENTION = ".txt";
	public static final String HEADER_PROCESS = "ProcessName";
	public static final String HEADER_TEST_CONFIGURATION = "TestConfiguration";
	public static final String HEADER_RECORD_NUMBER = "RecordNumber";
	public static final String HEADER_CPU_USAGE = "CpuUsage(%)";
	public static final String HEADER_MEMORY_USAGE = "MemoryUsage(%)";
	public static final String RESULT_FILE_HEADER_FORMAT = "%-10s%-20s%-10s%-20s%-20s";
	public static final String RESULT_FILE_LINE_FORMAT = "%-2s%-8s%-22s%-10s%-20s%-20s";
}