package com.redhat.os.svt.osperf.support.helper;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.io.Charsets;
import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.redhat.os.svt.osperf.appperf.PerfReportData;
import com.redhat.os.svt.osperf.support.configuration.AppPerfConfig;

/**
 * Writes the test results data into a consolidated file with the measurables. 
 * 
 * @author schituku
 *
 */
public class PerfTestResultWriter {
	
	private static final Logger LOG = LoggerFactory.getLogger(PerfTestResultWriter.class);
	
	/**
	 * creates a consolidated results data from the test results and writes it to a file
	 */
	public void writeTestResultsToFile(){
		
		List<PerfReportData> reportData = PerfTestResultParser.getReportData();
		
		File resultsFile = new File(AppPerfConfig.CONSOLIDATED_RESULTS_FILE_NAME);
		List<String> resultLines = new ArrayList<>();
		resultLines.add(String.format(AppPerfConfig.RESULT_FILE_HEADER_FORMAT,
										AppPerfConfig.HEADER_USERS,AppPerfConfig.HEADER_TEST_APP_NAME,
										AppPerfConfig.HEADER_TOTAL_HITS,AppPerfConfig.HEADER_TOTAL_REQUESTS,
										AppPerfConfig.HEADER_ERROR_PERCENTAGE,
										AppPerfConfig.HEADER_AVERAGE_RESPONSE_TIME,AppPerfConfig.HEADER_90_PERCENTILE_TIME));
		
		for (PerfReportData jmeterReportData : reportData) {
			resultLines.add(
						  String.format(AppPerfConfig.RESULT_FILE_LINE_FORMAT," ",
								  jmeterReportData.getNumOfUsers(),
								  jmeterReportData.getTestAppName(),
								  jmeterReportData.getNumOfAppLoops(),
								  jmeterReportData.getTotalRequests(),
								  jmeterReportData.getRequestErrorPercentage(),
								  jmeterReportData.getAvgResponseTime(),
								  jmeterReportData.getNinetyPercentileTime()  
								  )
					);
			}
		try {
			FileUtils.writeLines(resultsFile, Charsets.UTF_8.toString(),
					resultLines	, true);
		} catch (IOException e) {
			LOG.debug("Error in writing to the file");
			e.printStackTrace();
		}
	}
}