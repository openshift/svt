package com.redhat.os.svt.osperfscale;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import org.apache.commons.csv.CSVRecord;
import org.apache.commons.math3.stat.descriptive.DescriptiveStatistics;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.redhat.os.svt.osperfscale.utils.CSVParser;

public class ResultProcessor {
	
	private static final Logger LOG = LoggerFactory.getLogger(ResultProcessor.class);
	
	public static void processResults(){
		
		try {
			Iterable<CSVRecord> records = CSVParser.parse("");
			List<Double> responseTimes = new ArrayList<Double>();
			DescriptiveStatistics responseStats = new DescriptiveStatistics();
			for (CSVRecord csvRecord : records) {
				responseTimes.add(new Double(Double.parseDouble(csvRecord.get(1))));
				responseStats.addValue(Double.parseDouble(csvRecord.get(1))/1000);
			}
			Collections.sort(responseTimes);
			Double total= new Double(0.0);
			for (int i = 0; i < responseTimes.size(); i++) {
				LOG.debug("responseTime: "+responseTimes.get(i));
				total += responseTimes.get(i);
				
			}
			Double average = (total/ (responseTimes.size()* 1.0));
			average = average / 1000.0;
			
			
			Double min = responseTimes.get(0);
			Double max = responseTimes.get(responseTimes.size()-1);
			LOG.debug("Min: "+ (min/1000.0));
			LOG.debug("Max: "+(max/1000.0));
			LOG.debug("Average: "+average);
			LOG.debug("===============");
			LOG.debug("Min: "+ responseStats.getMin());
			LOG.debug("Max: "+ responseStats.getMax());
			LOG.debug("Average: "+responseStats.getMean());
			LOG.debug("90 Percentile: "+ responseStats.getPercentile(90.0));
			
			
		} catch (IOException e) {
			e.printStackTrace();
		}
	}

}
