package org.redhat.jmeter.elasticsearch;

import org.apache.jmeter.assertions.AssertionResult;
import org.apache.jmeter.config.Arguments;
import org.apache.jmeter.samplers.SampleResult;
import org.apache.jmeter.visualizers.backend.AbstractBackendListenerClient;
import org.apache.jmeter.visualizers.backend.BackendListenerContext;
import org.elasticsearch.client.Client;
import org.elasticsearch.client.transport.TransportClient;
import org.elasticsearch.common.transport.InetSocketTransportAddress;

import java.net.InetAddress;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.text.SimpleDateFormat;
import java.util.Date;

/*
* In order to implement a custom backend listener inside Jmeter, this code  uses the following components:
* ElasticSearch Java API: https://www.elastic.co/guide/en/elasticsearch/client/java-api/current/index.html
* TransportClient: https://www.elastic.co/guide/en/elasticsearch/client/java-api/current/transport-client.html
* Jmeter backendListener: http://jmeter.apache.org/api/org/apache/jmeter/visualizers/backend/BackendListenerClient.html
*
The BackendListenerClient interface has the following methods:

        setupTest/teardownTest: Initialization/cleanup methods . Called once each time the test is run.
        getDefaultParameters: Get parameters from the GUI.
        handleSampleResults: JMeter invokes this method to provide the results of the tests.
                             A List of SampleResult is provided as input , the size of the list will probably be up to
                             the Async Queue Size field that is specified when the Listener is configured
        createSampleResult: This allows you to create a copy of the SampleResult so that if you modify it in some way,
                             it doesn't change anything for the rest of the Listeners.
*
*/

public class ELKBackendListenerClient extends AbstractBackendListenerClient {
    private Client client;
    private String index;
    private String dateTimeAppendFormat;
    private String sampleType;
    private String testRunID;
    private long offset;
    private static final int DEFAULT_ELASTICSEARCH_PORT = 9300;
    private static final String TIMESTAMP = "timestamp";
    private static final String VAR_DELIMITER = "~";
    private static final String VALUE_DELIMITER = "=";

    @Override
    public void handleSampleResults(List<SampleResult> results, BackendListenerContext context) {
        String indexName = index;

        for (SampleResult result : results) {
            Map<String, Object> jsonObject = resultsMap(result);
            if (dateTimeAppendFormat != null) {
                SimpleDateFormat sdf = new SimpleDateFormat(dateTimeAppendFormat);
                indexName = index + sdf.format(jsonObject.get(TIMESTAMP));
            }
            client.prepareIndex(indexName, sampleType).setSource(jsonObject).execute().actionGet();
        }
    }

    private Map<String, Object> resultsMap(SampleResult result) {
        Map<String, Object> map = new HashMap<String, Object>();
        String[] sampleLabels = result.getSampleLabel().split(VAR_DELIMITER);
        map.put("SampleLabel", sampleLabels[0]);
        for (int i = 1; i < sampleLabels.length; i++) {
            String[] varNameAndValue = sampleLabels[i].split(VALUE_DELIMITER);
            map.put(varNameAndValue[0], varNameAndValue[1]);
        }

        map.put("ResponseTime", result.getTime());
        map.put("ElapsedTime", result.getTime());
        map.put("ResponseCode", result.getResponseCode());
        map.put("ResponseMessage", result.getResponseMessage());
        map.put("ThreadName", result.getThreadName());
        map.put("DataType", result.getDataType());
        map.put("Success", String.valueOf(result.isSuccessful()));
        map.put("GrpThreads", result.getGroupThreads());
        map.put("AllThreads", result.getAllThreads());
        map.put("URL", result.getUrlAsString());
        map.put("Latency", result.getLatency());
        map.put("ConnectTime", result.getConnectTime());
        map.put("SampleCount", result.getSampleCount());
        map.put("ErrorCount", result.getErrorCount());
        map.put("Bytes", result.getBytes());
        map.put("BodySize", result.getBodySize());
        map.put("ContentType", result.getContentType());
        map.put("IdleTime", result.getIdleTime());
        map.put(TIMESTAMP, new Date(result.getTimeStamp()));
        map.put("NormalizedTimestamp", new Date(result.getTimeStamp() - offset));
        map.put("StartTime", new Date(result.getStartTime()));
        map.put("EndTime", new Date(result.getEndTime()));
        map.put("RunId", testRunID);

        AssertionResult[] assertions = result.getAssertionResults();
        int count = 0;
        if (assertions != null) {
            Map<String, Object>[] assertionArray = new HashMap[assertions.length];
            for (AssertionResult assertionResult : assertions) {
                Map<String, Object> assertionMap = new HashMap<String, Object>();
                assertionMap.put("Failure", assertionResult.isError() || assertionResult.isFailure());
                assertionMap.put("FailureMessage", assertionResult.getFailureMessage());
                assertionMap.put("Name", assertionResult.getName());
                assertionArray[count++] = assertionMap;
            }
            map.put("Assertions", assertionArray);
        }
        return map;
    }

    @Override
    public void setupTest(BackendListenerContext context) throws Exception {
        String elk_cluster = context.getParameter("elk_cluster");
        String[] servers = elk_cluster.split(",");
        testRunID = context.getParameter("testRunID");
        sampleType = context.getParameter("sampleType");

        index = context.getParameter("index");
        dateTimeAppendFormat = context.getParameter("dateTimeAppendFormat");
        if (dateTimeAppendFormat != null && dateTimeAppendFormat.trim().equals("")) {
            dateTimeAppendFormat = null;
        }

        String nt = context.getParameter("normalizedTime");
        if (nt != null && nt.trim().length() > 0) {
            SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSSX");
            Date d = sdf.parse(nt);
            long normalizedDate = d.getTime();
            Date now = new Date();
            offset = now.getTime() - normalizedDate;
        }

        client = TransportClient.builder().build()
                .addTransportAddress(new InetSocketTransportAddress(InetAddress.getByName(
                        servers[0]),
                        DEFAULT_ELASTICSEARCH_PORT));

        super.setupTest(context);
    }

    @Override
    public Arguments getDefaultParameters() {
        Arguments arguments = new Arguments();
        arguments.addArgument("elk_cluster", "elasticsearch_hostname:" + DEFAULT_ELASTICSEARCH_PORT);
        arguments.addArgument("index", "jmeter-elasticsearch");
        arguments.addArgument("sampleType", "SampleResult");
        arguments.addArgument("dateTimeAppendFormat", "-yyyy-MM-DD");
        arguments.addArgument("normalizedTime", "2015-01-01 00:00:00.000-00:00");
        arguments.addArgument("testRunID", "${__UUID()}");
        return arguments;
    }

    @Override
    public void teardownTest(BackendListenerContext context) throws Exception {
        client.close();
        super.teardownTest(context);
    }

}
