package com.redhat.os.svt.osperf.support.charts;

import java.io.File;
import java.io.IOException;
import java.util.List;

import org.jfree.chart.ChartFactory;
import org.jfree.chart.ChartUtilities;
import org.jfree.chart.JFreeChart;
import org.jfree.chart.plot.PlotOrientation;
import org.jfree.data.category.DefaultCategoryDataset;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.redhat.os.svt.osperf.appperf.PerfReportData;
import com.redhat.os.svt.osperf.appperf.PerfTestPlanCreator;
import com.redhat.os.svt.osperf.support.configuration.AppPerfConfig;
import com.redhat.os.svt.osperf.support.helper.PerfTestResultParser;

/**
 * Creates graphs out of the test results extracted from the test runs. 
 * @author schituku
 *
 */
public class GraphCreator {
	
	protected final Logger LOG = LoggerFactory.getLogger(GraphCreator.class);
	
	protected static final String AVG_RESPONSE_TIME_GRAPH_TITLE = "NUMBER OF USERS - ";
	protected static final String AVG_RESPONSE_TIME_GRAPH_X_AXIS_TITLE = "TotalHits";
	protected static final String AVG_RESPONSE_TIME_GRAPH_Y_AXIS_TITLE = "AvgTime(ms)";

	protected static final String NINETY_PERCENTILE_GRAPH_TITLE = "TotalHits vs 90PercentileTime";
	protected static final String NINETY_PERCENTILE_GRAPH_X_AXIS_TITLE = "TotalHits";
	protected static final String NINETY_PERCENTILE_GRAPH_Y_AXIS_TITLE = "90PercentileTime(ms)";

	public void createSimpleLineChart(){
		
		List<PerfReportData> reportData = PerfTestResultParser.getReportData();
		
		DefaultCategoryDataset avgResponseLineChartDataset = new DefaultCategoryDataset();
		DefaultCategoryDataset percentile90LineChartDataset = new DefaultCategoryDataset();
		
		for (PerfReportData jmeterReportData : reportData) {
			String key = jmeterReportData.getNumOfUsers()+ PerfTestPlanCreator.SEPERATOR_IN_TEST_PLAN_NAME+jmeterReportData.getNumOfAppLoops();
			
		     avgResponseLineChartDataset.addValue( Integer.parseInt(jmeterReportData.getAvgResponseTime())
		    		 						, "Scenarios" , key); 
		     percentile90LineChartDataset.addValue( Integer.parseInt(jmeterReportData.getNinetyPercentileTime())
						, "Scenarios" , key); 
		}
		
	    JFreeChart avgResponseLineChartObject = 
	    		  		ChartFactory.createLineChart(
	    		  				"Test Scenarios vs Average Response Times","Test Scenarios",
	    		  				"Avg Response Time (ms)",
	    		  				avgResponseLineChartDataset,PlotOrientation.VERTICAL,
	    		  				true,true,false);

	    JFreeChart percentile90LineChartObject = 
		  				ChartFactory.createLineChart(
		  						"Test Scenarios vs 90 percentile Times","Test Scenarios",
		  						"90 percentile time (ms)",
		  						percentile90LineChartDataset,PlotOrientation.VERTICAL,
		  						true,true,false);
	    int width = 640; /* Width of the image */
	    int height = 480; /* Height of the image */ 
	    File avgResponselineChartPNG = new File( AppPerfConfig.AVERAGE_RESPONSE_GRAPH_FILE_NAME );
	    File percentile90lineChartPNG = new File( AppPerfConfig.PERCENTILE_90_GRAPH_FILE_NAME );
	    try {
			ChartUtilities.saveChartAsPNG(avgResponselineChartPNG ,avgResponseLineChartObject, width ,height);
			ChartUtilities.saveChartAsPNG(percentile90lineChartPNG ,percentile90LineChartObject, width ,height);
		}catch (IOException e) {
			LOG.debug("Exception in file manipulation");
		}
	}
}