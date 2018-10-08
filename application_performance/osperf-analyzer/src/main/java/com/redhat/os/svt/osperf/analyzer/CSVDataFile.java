package com.redhat.os.svt.osperf.analyzer;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.redhat.os.svt.osperf.analyzer.support.configuration.AppPerfConfig;

public class CSVDataFile {

	private static final Logger LOG = LoggerFactory.getLogger(CSVDataFile.class);
	
	public static void scrubFileHeaders(File testFile) {
		try {
			List<String> lines = FileUtils.readLines(testFile, "UTF-8");
			LOG.debug("The content of the line in file "+testFile.getAbsolutePath()+" are:");
			LOG.debug(lines.get(0));
			String[] headers = lines.get(0).split(",");
			StringBuffer newHeaderLine=new StringBuffer();
			String[] processNames = { AppPerfConfig.PROCESS_RSYSLOGD, AppPerfConfig.PROCESS_JOURNALD };
			for (int i = 0; i < processNames.length; i++) {
				newHeaderLine = new StringBuffer();
				for (String header : headers) {
//					LOG.debug(header+" "+processNames[i]);
					if (header.contains(processNames[i])) {
						header = processNames[i];
					}
					newHeaderLine.append(header).append(",");
				}
				headers = newHeaderLine.toString().split(",");
			}
			lines.remove(0);
			List<String> newlines = new ArrayList<String>();
			LOG.debug("== the new line is ==");
			LOG.debug(newHeaderLine.toString());
			newlines.add(newHeaderLine.toString());
			for (String line : lines) {
				newlines.add(line);
			}
			String newFileName = AppPerfConfig.TEST_OUTPUT_FILES_DIRECTORY + testFile.getName();
			FileUtils.writeLines(new File(newFileName), newlines);
		} catch (IOException e) {
			e.printStackTrace();
		}
	}
}