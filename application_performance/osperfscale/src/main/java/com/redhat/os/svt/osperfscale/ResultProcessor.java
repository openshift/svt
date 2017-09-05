package com.redhat.os.svt.osperfscale;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.apache.commons.csv.CSVRecord;
import org.apache.commons.io.FileUtils;
import org.apache.commons.math3.stat.descriptive.DescriptiveStatistics;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.redhat.os.svt.osperfscale.common.AppConstants;
import com.redhat.os.svt.osperfscale.common.PerfTestParameter;
import com.redhat.os.svt.osperfscale.common.ResultObject;
import com.redhat.os.svt.osperfscale.common.ResultRecord;
import com.redhat.os.svt.osperfscale.common.TestConfig;
import com.redhat.os.svt.osperfscale.utils.CSVParser;
import com.redhat.os.svt.osperfscale.utils.ConfigYamlParser;

public class ResultProcessor {
	
	private static final Logger LOG = LoggerFactory.getLogger(ResultProcessor.class);
	
	public static Map<String, ResultObject> resultsMap;
	
	public static Map<String, ResultObject> getResults(){
		if(ResultProcessor.resultsMap==null || ResultProcessor.resultsMap.isEmpty()){
			ResultProcessor.processResults();
		}
		return ResultProcessor.resultsMap;
	}
	
	public static void processResults(){
		ResultProcessor.resultsMap = new HashMap<String, ResultObject>();
		try {
			// add header to the file
			ResultProcessor.addHeaderToResults();
			Iterable<CSVRecord> records = CSVParser.parse(AppConstants.RESULT_FILE_WITH_HEADER);
			DescriptiveStatistics responseStats = new DescriptiveStatistics();
			List<ResultRecord> resultRecords = new ArrayList<ResultRecord>();
			for (CSVRecord csvRecord : records) {
				responseStats.addValue(Double.parseDouble(csvRecord.get(1))/1000);
				resultRecords.add(ResultRecord.convertToResultRecord(csvRecord));
			}
//			LOG.debug("ResponseTime: "+ resultRecords.get(0).getResponseTime());
//			LOG.debug("HTTP Method: "+ resultRecords.get(0).getHttpMethod());
//			LOG.debug("HTTP URL: "+resultRecords.get(0).getHttpURL());
//			LOG.debug("Average: "+responseStats.getGeometricMean());
//			LOG.debug("90Percentile: "+responseStats.getPercentile(90.00));
			// get the test name
			ConfigYamlParser parser = new ConfigYamlParser();
			TestConfig testConfig = parser.parseYaml(TestConfig.TEST_CONFIG_FILE_NAME);
			List<PerfTestParameter> requestParams = testConfig.getTestParameters();
			Map<String, PerfTestParameter> requestParamsMap = new HashMap<String, PerfTestParameter>();
			for (PerfTestParameter perfTestParameter : requestParams) {
				requestParamsMap.put(perfTestParameter.getAppURL(), perfTestParameter);
			}
			
			Set<String> uniqueURLs = new HashSet<String>();
			for (ResultRecord resultRecord : resultRecords) {
				uniqueURLs.add(resultRecord.getHttpURL());
			}
//			int i=0;
			
			ResultObject tempResult;
			for (String uniqueURL : uniqueURLs) {
//				LOG.debug(++i+"."+uniqueURL);
				tempResult = new ResultObject();
				tempResult.setUrl(uniqueURL);
				ResultProcessor.resultsMap.put(uniqueURL, tempResult);
			}
			PerfTestParameter tempParam;
			String testName;
			for (ResultRecord resultRecord : resultRecords) {
				if(resultRecord.getHttpResponseCode()==200){
					tempResult = ResultProcessor.resultsMap.get(resultRecord.getHttpURL());
					tempResult.getResponseTimes().add(new Long(resultRecord.getResponseTime()));
					tempResult.getResponseStats().addValue((double)resultRecord.getResponseTime());
					tempParam = requestParamsMap.get(resultRecord.getHttpURL());
					testName = tempParam.getTestSuiteName();
					tempResult.setTestName(testName);            
				}
			}
			
			for (Map.Entry<String,ResultObject> entry : ResultProcessor.resultsMap.entrySet()) {
				  String appURL = entry.getKey();
				  tempResult = entry.getValue();

				  LOG.debug("For Test: "+tempResult.getTestName()+" URL: "+appURL+" total responses are: "+tempResult.getResponseTimes().size() +
						      " Avg response is: "+tempResult.getResponseStats().getGeometricMean() +
						       " 90 precentile response is: "+tempResult.getResponseStats().getPercentile(90.00) 
						  );
//				  List<Long> responses = value.getResponseTimes();
//				  for (Long response : responses) {
//					LOG.debug("The response time is: "+response);
//				  }
				}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	public static void addHeaderToResults(){
		File fileWithHeader = new File(AppConstants.RESULT_FILE_WITH_HEADER);
		File resultsFile = new File(AppConstants.RESULT_FILE);
		
		List<String> headerRecord = new ArrayList<String>();
		headerRecord.add(AppConstants.HEADER_STRING);
		try {
			FileUtils.writeLines(fileWithHeader, headerRecord);
			FileUtils.writeLines(fileWithHeader, 
					               FileUtils.readLines(resultsFile, AppConstants.PLATFORM_DEFAULT_ENCODING), 
					               true);
		} catch (IOException e) {
			e.printStackTrace();
		}
	}
}