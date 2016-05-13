package com.redhat.os.svt.osperf.support.helper;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.List;

import org.apache.commons.io.Charsets;
import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.redhat.os.svt.osperf.appperf.PerfReportData;
import com.redhat.os.svt.osperf.support.configuration.AppPerfConfig;

public class PerfTestResultParser {
	
	private static final Logger LOG = LoggerFactory.getLogger(PerfTestResultParser.class);
	
	/**
	 * returns the report data for all the test plans for which the 
	 * the tests have run.
	 *  
	 * @return
	 */
	public static List<PerfReportData> getReportData(){
		
		List<PerfReportData> reportData = new ArrayList<>();

		// get all tests from jmeter folder
		String [] jmeterFileExtentions = new String [] {AppPerfConfig.JMETER_FILES_EXTENSION};
		
		Collection<File> reportFiles = FileUtils.listFiles(new File(AppPerfConfig.JMETER_FILES_DIRECTORY), 
								jmeterFileExtentions, false);
		
		for (File aFile : reportFiles) {
			
			PerfReportData aReportData = new PerfReportData();
			aReportData.setTestPlanName(aFile.getName());
			String reportFileName = aFile.getName().replace(AppPerfConfig.JMETER_FILES_EXTENSION, 
					AppPerfConfig.JMETER_TEST_REPORT_FILE_EXTENTION);
			LOG.info("Processing the report File name: {} ",reportFileName);
			try {
				List<String> reportLines = FileUtils.readLines(
						new File(AppPerfConfig.JMETER_TEST_REPORT_DIRECTORY+reportFileName), 
						Charsets.UTF_8.toString());
				// the first occurence of average in the file corresponds to response average
				boolean firstOccurenceOfAvg = false;
				aReportData.setRequestErrorPercentage("0");
				aReportData.setTotalRequests("0");
				for (String aReportLine : reportLines) {
					String [] reportLineSplits=null;
					
					if(aReportLine.contains("requests:")){
						reportLineSplits = aReportLine.split(":");
						aReportData.setTotalRequests(reportLineSplits[1].trim());
					}else if(aReportLine.contains("errors:")){
						reportLineSplits = aReportLine.split(":");
						aReportData.setRequestErrorPercentage(reportLineSplits[1].trim());
					}else if(aReportLine.contains("average:") && !firstOccurenceOfAvg){
						firstOccurenceOfAvg = true;
						reportLineSplits = aReportLine.split(":");
						aReportData.setAvgResponseTime(reportLineSplits[1].trim());
					}else if(aReportLine.contains("90%")){
						// 90% contains the test 90% and there is only one occurence of it in the file.
						reportLineSplits = aReportLine.split("%");
						aReportData.setNinetyPercentileTime(reportLineSplits[1].trim());
						break;
					}
				}
			} catch (IOException e) {
				LOG.debug("ERROR Reading the file");
				e.printStackTrace();
			} catch (Exception e) {
				LOG.debug("ERROR Reading the file");
			}
			reportData.add(aReportData);
		}
		Collections.sort(reportData);
		
		return reportData;
	}
	
	/**
	 * Returns a list of unique number of users in the report data list.
	 * 
	 * @return list of unique number of users in the test results.
	 */
	public static List<String> getUniqueUsersFromReportData(List<PerfReportData> reportData){
		
		List<String> users = new ArrayList<>();
		String prevUser=null;
		String currUser=null;
		
		for (PerfReportData perfReportData : reportData) {
			currUser = Integer.toString(perfReportData.getNumOfUsers()); 
		     if(! currUser.equals(prevUser)){
		    	 users.add(currUser);
		     }
		     prevUser =currUser;
		}
		return users;
	}
}