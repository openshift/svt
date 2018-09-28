package com.redhat.os.svt.osperf.tests;

import java.io.File;
import java.io.IOException;

import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

import com.redhat.os.svt.osperf.analyzer.support.charts.GraphCreator;
import com.redhat.os.svt.osperf.analyzer.support.configuration.AppPerfConfig;

public class PrePerfTests {

	private final Logger LOG = LoggerFactory.getLogger(PrePerfTests.class);

	@BeforeClass(enabled = true)
	public void oneTimeSetup() {
		// create or clear the results folder.
		try {
			File resultsDirectory = new File(AppPerfConfig.TEST_RESULTS_DIRECTORY);
			if (!resultsDirectory.isDirectory()) {
				FileUtils.forceMkdir(resultsDirectory);
			} else {
				FileUtils.cleanDirectory(resultsDirectory);
			}
		} catch (IOException e) {
			e.printStackTrace();
			LOG.debug("Error cleaning the results directory");
		}
	}

	@Test(enabled = true)
	public void testCreateCSVGraphs() {
		LOG.info("Running the test create CSV graphs ");

		GraphCreator graphCreator = new GraphCreator();
		graphCreator.createATestRunGraph(AppPerfConfig.PROCESS_RSYSLOGD, AppPerfConfig.MEASURABLE_CPU);
		graphCreator.createATestRunGraph(AppPerfConfig.PROCESS_RSYSLOGD, AppPerfConfig.MEASURABLE_MEMORY);
		graphCreator.createATestRunGraph(AppPerfConfig.PROCESS_JOURNALD, AppPerfConfig.MEASURABLE_CPU);
		graphCreator.createATestRunGraph(AppPerfConfig.PROCESS_JOURNALD, AppPerfConfig.MEASURABLE_MEMORY);
		graphCreator.createATestRunGraph(AppPerfConfig.PROCESS_ROUTER_PERF, AppPerfConfig.MEASURABLE_TOTAL_HITS);
		graphCreator.createATestRunGraph(AppPerfConfig.PROCESS_ROUTER_PERF, AppPerfConfig.MEASURABLE_HITS_PER_SEC);
	}
}