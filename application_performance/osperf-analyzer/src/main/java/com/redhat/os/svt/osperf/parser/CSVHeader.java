package com.redhat.os.svt.osperf.parser;

import com.redhat.os.svt.osperf.analyzer.support.configuration.AppPerfConfig;

public class CSVHeader {

	public static final String JOURNALD = AppPerfConfig.PROCESS_JOURNALD;
	public static final String RSYSLOG = AppPerfConfig.PROCESS_RSYSLOGD;
	public static final String USERS = AppPerfConfig.USERS;
	public static final String TOTAL_HITS = AppPerfConfig.MEASURABLE_TOTAL_HITS;
	public static final String HITS_PER_SEC = AppPerfConfig.MEASURABLE_HITS_PER_SEC;
	
	
	
	public static final String DATE_FORMAT_IN_CSV = "yyyy-MM-dd HH:mm:ss +hhmm";
}
