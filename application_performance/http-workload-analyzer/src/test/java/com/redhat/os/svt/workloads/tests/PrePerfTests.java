package com.redhat.os.svt.workloads.tests;

import com.redhat.os.svt.workloads.analyzer.support.configuration.WorkloadAnalyzerConfig;
import com.redhat.os.svt.workloads.parser.WorkloadParser;
import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

import java.io.File;
import java.io.IOException;

public class PrePerfTests {

	private final Logger LOG = LoggerFactory.getLogger(PrePerfTests.class);

	@BeforeClass(enabled = true)
	public void oneTimeSetup() {
		// create or clear the results folder.
		try {
			LOG.info("Cleaning input files");
			File resultsDirectory = new File(WorkloadAnalyzerConfig.TEST_RESULTS_DIRECTORY);
			if (!resultsDirectory.isDirectory()) {
				FileUtils.forceMkdir(resultsDirectory);
			} else {
				FileUtils.cleanDirectory(resultsDirectory);
			}
			File inputDirectory = new File(WorkloadAnalyzerConfig.TEST_INPUT_FILES_DIRECTORY);
			if (!inputDirectory.isDirectory()) {
				FileUtils.forceMkdir(inputDirectory);
			} else {
				FileUtils.cleanDirectory(inputDirectory);
			}
		} catch (IOException e) {
			e.printStackTrace();
			LOG.debug("Error cleaning the results directory");
		}
	}

	@Test(enabled = false)
	public void testGetWorkloadReport() {
		LOG.info("Running the test report workload ");
		WorkloadParser aParser = new WorkloadParser();
		String url =
				"http://pbench.perf.lab.eng.bos.redhat.com/results/EC2::scale-ci-http-br5cc/http-2020-04-07_18.13.56-OpenShiftSDN/pbench-user-benchmark_0010r-200cpt-0000d_ms-100ka-ytlsru-120s-http-OpenShiftSDN_2020.04.07T18.10.26/http-2020-04-07_18.13.56-OpenShiftSDN.tar.xz";
		try {
			aParser.downloadReport(url);
		} catch (IOException e) {
			e.printStackTrace();
		}
		aParser.getReport();
	}

	@Test(enabled = false)
	public void testDownloadWorkloadReport() {
		LOG.info("Running the test report workload ");
		WorkloadParser aParser = new WorkloadParser();
		String url =
		 "http://pbench.perf.lab.eng.bos.redhat.com/results/EC2::scale-ci-http-br5cc/http-2020-04-07_18.13.56-OpenShiftSDN/pbench-user-benchmark_0010r-200cpt-0000d_ms-100ka-ytlsru-120s-http-OpenShiftSDN_2020.04.07T18.10.26/http-2020-04-07_18.13.56-OpenShiftSDN.tar.xz";
		try {
			aParser.downloadReport(url);
		} catch (IOException e) {
			e.printStackTrace();
		}
	}

	@Test(enabled = true)
	public void testDownloadReports(){
		LOG.info("Running the test report workload ");
		WorkloadParser aParser = new WorkloadParser();
		String urls =
				"http://pbench.perf.lab.eng.bos.redhat.com/results/EC2::scale-ci-http-bjvm5/http-2020-04-08_14.21.00-OpenShiftSDN_I1/pbench-user-benchmark_0010r-200cpt-0000d_ms-100ka-ytlsru-120s-http-OpenShiftSDN_I1_2020.04.08T14.17.07/http-2020-04-08_14.21.00-OpenShiftSDN_I1.tar.xz,"+
				"http://pbench.perf.lab.eng.bos.redhat.com/results/EC2::scale-ci-http-vj62j/http-2020-04-08_18.06.14-OpenShiftSDN_I2/pbench-user-benchmark_0010r-200cpt-0000d_ms-100ka-ytlsru-120s-http-OpenShiftSDN_I2_2020.04.08T18.02.22/http-2020-04-08_18.06.14-OpenShiftSDN_I2.tar.xz,"+
				"http://pbench.perf.lab.eng.bos.redhat.com/results/EC2::scale-ci-http-87tm4/http-2020-04-08_18.46.58-OpenShiftSDN_I3/pbench-user-benchmark_0010r-200cpt-0000d_ms-100ka-ytlsru-120s-http-OpenShiftSDN_I3_2020.04.08T18.43.00/http-2020-04-08_18.46.58-OpenShiftSDN_I3.tar.xz,"+
				"http://pbench.perf.lab.eng.bos.redhat.com/results/EC2::scale-ci-http-xpbl5/http-2020-04-08_21.22.33-OVNKubernetes_I1/pbench-user-benchmark_0010r-200cpt-0000d_ms-100ka-ytlsru-120s-http-OVNKubernetes_I1_2020.04.08T21.19.19/http-2020-04-08_21.22.33-OVNKubernetes_I1.tar.xz";
//				"http://pbench.perf.lab.eng.bos.redhat.com/results/EC2::scale-ci-http-vj62j/http-2020-04-08_18.06.14-OpenShiftSDN_I2/pbench-user-benchmark_0010r-200cpt-0000d_ms-100ka-ytlsru-120s-http-OpenShiftSDN_I2_2020.04.08T18.02.22/http-2020-04-08_18.06.14-OpenShiftSDN_I2.tar.xz,"+
//				"http://pbench.perf.lab.eng.bos.redhat.com/results/EC2::scale-ci-http-87tm4/http-2020-04-08_18.46.58-OpenShiftSDN_I3/pbench-user-benchmark_0010r-200cpt-0000d_ms-100ka-ytlsru-120s-http-OpenShiftSDN_I3_2020.04.08T18.43.00/http-2020-04-08_18.46.58-OpenShiftSDN_I3.tar.xz,"+
//				"http://pbench.perf.lab.eng.bos.redhat.com/results/EC2::scale-ci-http-bjvm5/http-2020-04-08_14.21.00-OpenShiftSDN_I1/pbench-user-benchmark_0010r-200cpt-0000d_ms-100ka-ytlsru-120s-http-OpenShiftSDN_I1_2020.04.08T14.17.07/http-2020-04-08_14.21.00-OpenShiftSDN_I1.tar.xz";
//		String urls =
//				"http://pbench.perf.lab.eng.bos.redhat.com/results/EC2::scale-ci-http-bjvm5/http-2020-04-08_14.21.00-OpenShiftSDN_I1/pbench-user-benchmark_0010r-200cpt-0000d_ms-100ka-ytlsru-120s-http-OpenShiftSDN_I1_2020.04.08T14.17.07/http-2020-04-08_14.21.00-OpenShiftSDN_I1.tar.xz";
		try {
			aParser.analyzereports(urls);
		} catch (IOException e) {
			e.printStackTrace();
		}
	}
}