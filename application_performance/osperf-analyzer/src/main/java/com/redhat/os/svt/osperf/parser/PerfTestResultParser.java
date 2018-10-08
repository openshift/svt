package com.redhat.os.svt.osperf.parser;

import java.io.File;
import java.io.IOException;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

import org.apache.commons.csv.CSVRecord;
import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.redhat.os.svt.osperf.analyzer.CSVDataFile;
import com.redhat.os.svt.osperf.analyzer.PerfReportData;
import com.redhat.os.svt.osperf.analyzer.support.configuration.AppPerfConfig;

public class PerfTestResultParser {
	
	private static final Logger LOG = LoggerFactory.getLogger(PerfTestResultParser.class);
	
	/**
	 * returns the report data for all the test plans for which the 
	 * the tests have run.
	 *  
	 * @return
	 */
	public static List<PerfReportData> getReportData(String processName, String measurable){
		
		List<PerfReportData> reportData = new ArrayList<>();

		String [] csvFileExtentions = new String [] {AppPerfConfig.CSV_FILES_EXTENSION};
		
		Collection<File> reportFiles = FileUtils.listFiles(new File(AppPerfConfig.TEST_INPUT_FILES_DIRECTORY), 
								csvFileExtentions, false);
		
		for (File aFile : reportFiles) {
			if(aFile.getName().contains(measurable.toLowerCase())) {

			    CSVDataFile.scrubFileHeaders(aFile);
				PerfReportData aReportData = new PerfReportData();
				aReportData.setTestRunName(aFile.getName());
				LOG.info("Processing the report File name: {} ",aFile.getName());
				String newFileName = AppPerfConfig.TEST_OUTPUT_FILES_DIRECTORY + aFile.getName();
				try {
					
					Iterable<CSVRecord> records = new CSVParser().parse(newFileName);
					for (CSVRecord record : records) {
						aReportData.setProcessName(processName);
						aReportData.setTestRunName(aFile.getName());
						if(processName.compareTo(AppPerfConfig.PROCESS_ROUTER_PERF)==0) {
							LOG.debug("The users: " + record.get(CSVHeader.USERS)+"total-hits: " + record.get(measurable));
							aReportData.setxAxisValue(Long.parseLong(record.get(CSVHeader.USERS)));
							aReportData.setyAxisValue(new BigDecimal(record.get(measurable)));
						}else {
							LOG.debug("The record number: " + record.getRecordNumber()+"rsyslog: " + record.get(CSVHeader.RSYSLOG)+"journald: " 
									+ record.get(CSVHeader.JOURNALD));
							aReportData.setxAxisValue(record.getRecordNumber());
							aReportData.setyAxisValue(new BigDecimal(record.get(processName)));
						}
						reportData.add(aReportData);
						aReportData = new PerfReportData();
					}
					
				} catch (IOException e) {
					e.printStackTrace();
				}

			}
		}
		return reportData;
	}
}