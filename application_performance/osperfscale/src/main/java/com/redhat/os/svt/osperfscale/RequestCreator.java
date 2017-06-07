package com.redhat.os.svt.osperfscale;

import java.io.FileWriter;
import java.util.ArrayList;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.gson.Gson;
import com.redhat.os.svt.osperfscale.common.AppConstants;
import com.redhat.os.svt.osperfscale.common.DelayObject;
import com.redhat.os.svt.osperfscale.common.PerfTestParameter;
import com.redhat.os.svt.osperfscale.common.RequestObject;
import com.redhat.os.svt.osperfscale.common.TestConfig;
import com.redhat.os.svt.osperfscale.utils.ConfigYamlParser;

public class RequestCreator {

	private static final Logger LOG = LoggerFactory.getLogger(RequestCreator.class);

	public void createRequest() {
		try {
			ConfigYamlParser parser = new ConfigYamlParser();
			TestConfig testConfig = parser.parseYaml(TestConfig.TEST_CONFIG_FILE_NAME);
			List<PerfTestParameter> requestParams = testConfig.getTestParameters();
			List<RequestObject> request = new ArrayList<RequestObject>();
			RequestObject aRequest;

			for (PerfTestParameter perfTestParameter : requestParams) {
				long[] userArray = perfTestParameter.getNumberOfUsers();
				long[] delays = perfTestParameter.getIntervalBetweenAppHits();
				long[] rampUps = perfTestParameter.getRampUpTime();
				for (int i = 0; i < userArray.length; i++) {
					for (int j = 0; j < delays.length; j++) {
						for (int k = 0; k < rampUps.length; k++) {
							aRequest = new RequestObject();
							aRequest.setScheme(AppConstants.DEFAULT_SCHEME);
							aRequest.setTlsSessionReuse(AppConstants.DEFAULT_TLS_REUSE);
							aRequest.setHost(perfTestParameter.getAppURL());
							aRequest.setMethod(AppConstants.DEFAULT_HTTP_METHOD);
							aRequest.setPath(AppConstants.DEFAULT_PATH);
							DelayObject delay = new DelayObject();
							delay.setMin(AppConstants.DEFAULT_MIN_DELAY);
							delay.setMax((int)delays[j]);
							aRequest.setDelay(delay);
							aRequest.setClients((int)userArray[i]);
							aRequest.setRampUp((int)rampUps[k]);
							request.add(aRequest);
						}
					}
				}
			}
			RequestObject[] requestArray = request.toArray(new RequestObject[request.size()]);
			
			Gson gson = new Gson();
			FileWriter writer = new FileWriter(AppConstants.REQUEST_FILE);
            gson.toJson(requestArray, writer);
            writer.flush();

		} catch (Exception e) {
			e.printStackTrace();
			LOG.debug("EXCEPTION");
		}
	}
}