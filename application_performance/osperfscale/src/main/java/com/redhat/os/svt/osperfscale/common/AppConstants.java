package com.redhat.os.svt.osperfscale.common;

public class AppConstants {
	
	public static final String REQUEST_FILE = "results/request.json";
	public static final String RESULT_FILE = "results/response.csv";
	public static final String RESULT_FILE_WITH_HEADER = "results/responsewithheader.csv";
	// null will force to default to platform default encoding
	public static final String PLATFORM_DEFAULT_ENCODING = null;
	public static final String HEADER_STRING = 
			 "start_request,delay,status,written,read,method_and_url,thread_id,conn_id,conns,reqs,start,socket_writable,conn_est,err";
	
	public static final String TEST_RESULTS_DIRECTORY = "results";
	public static final String GRAPHS_DIRECTORY = "graphs";
	
	public static final String RESPONSE_GRAPH_FILE_NAME ="graphs/ResponseLineChart";
	public static final String RESPONSE_BAR_GRAPH_FILE_NAME ="graphs/ResponseBarChart";
	public static final String AVERAGE_RESPONSE_GRAPH_FILE_NAME ="graphs/AvgResponseLineChart";
	public static final String PERCENTILE_90_GRAPH_FILE_NAME ="graphs/percentile90LineChart";
	public static final String GRAPH_FILE_EXTENTION = ".png";
	public static final int    GRAPH_CHART_WIDTH = 1024;
	public static final int    GRAPH_CHART_HEIGHT = 768;
	public static final double GRAPH_CHART_SERIES_LINE_THICKNESS = 2.25f;
	
	public static final String DEFAULT_SCHEME = "http";
	public static final String DEFAULT_HTTP_METHOD = "GET";
	public static final String DEFAULT_PATH = "/";
	public static final boolean DEFAULT_TLS_REUSE = true;
	public static final int DEFAULT_MIN_DELAY = 0;
	public static final int DEFAULT_MAX_DELAY = 0;
	
	
}