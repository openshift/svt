package com.redhat.os.svt.workloads.analyzer.support.configuration;

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
public class WorkloadAnalyzerConfig {

	public static final String TEST_INPUT_FILES_DIRECTORY = "input/";
	public static final String TEST_RESULTS_DIRECTORY = "results";

	public static final String CONSOLIDATED_RESULTS_FILE_NAME ="results/ConsolidatedResults";
	public static final String CONSOLIDATED_RESULTS_FILE_EXTENTION = ".txt";
	public static final String COMPARISION_RESULTS_FILE_NAME ="results/ComparisionResults";
	public static final String COMPARISION_RESULTS_FILE_EXTENTION = ".txt";
}