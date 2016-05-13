package com.redhat.os.svt.osperf.support.charts;

import java.awt.BasicStroke;
import java.awt.Color;
import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.jfree.chart.ChartFactory;
import org.jfree.chart.ChartUtilities;
import org.jfree.chart.JFreeChart;
import org.jfree.chart.axis.AxisLocation;
import org.jfree.chart.axis.CategoryAxis;
import org.jfree.chart.axis.CategoryLabelPositions;
import org.jfree.chart.plot.CategoryPlot;
import org.jfree.chart.plot.PlotOrientation;
import org.jfree.chart.plot.XYPlot;
import org.jfree.chart.renderer.xy.XYLineAndShapeRenderer;
import org.jfree.data.category.DefaultCategoryDataset;
import org.jfree.data.xy.XYDataset;
import org.jfree.data.xy.XYSeries;
import org.jfree.data.xy.XYSeriesCollection;

import com.redhat.os.svt.osperf.appperf.PerfReportData;
import com.redhat.os.svt.osperf.appperf.PerfTestPlanCreator;
import com.redhat.os.svt.osperf.support.configuration.AppPerfConfig;
import com.redhat.os.svt.osperf.support.helper.PerfTestResultParser;

/**
 * Creates graphs for the test results gathered from the perf test runs.
 * 
 * @author schituku
 *
 */
public class GraphCreator3D extends GraphCreator {
	
	public static final String AVEGRAGE_RESPONSE_TIME = "AverageResponseTime";
	public static final String PERCENTILE_90_TIME = "Percentile90Time";
	
	public void createSimpleLineChart3D() {
		
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
	    		  		ChartFactory.createLineChart3D
	    		  				(
	    		  				"Number of  vs Average Response Times","Test Scenarios",
	    		  				"Avg Response Time (ms)",
	    		  				avgResponseLineChartDataset,PlotOrientation.VERTICAL,
	    		  				true,true,false);
	    
	    avgResponseLineChartObject.setBackgroundPaint(Color.WHITE);
	    CategoryPlot avgRespCategoryplot = avgResponseLineChartObject.getCategoryPlot();
	    avgRespCategoryplot.setBackgroundPaint(new Color(238, 238, 255));
	    avgRespCategoryplot.setDomainAxisLocation(AxisLocation.BOTTOM_OR_RIGHT);
               
        //Manages the Domain(x-axis) label position
        CategoryAxis avgRespCategoryaxis = avgRespCategoryplot.getDomainAxis();
        avgRespCategoryaxis.setCategoryLabelPositions(CategoryLabelPositions.DOWN_45);

	    JFreeChart percentile90LineChartObject = 
		  				ChartFactory.createLineChart3D(
		  						"Test Scenarios vs 90 percentile Times","Test Scenarios",
		  						"90 percentile time (ms)",
		  						percentile90LineChartDataset,PlotOrientation.VERTICAL,
		  						true,true,false);
	    percentile90LineChartObject.setBackgroundPaint(Color.WHITE);
	    CategoryPlot perc90Categoryplot = percentile90LineChartObject.getCategoryPlot();
	    perc90Categoryplot.setBackgroundPaint(new Color(238, 238, 255));
	    perc90Categoryplot.setDomainAxisLocation(AxisLocation.BOTTOM_OR_RIGHT);
               
        //Manages the Domain(x-axis) label position
        CategoryAxis perc90Categoryaxis = perc90Categoryplot.getDomainAxis();
        perc90Categoryaxis.setCategoryLabelPositions(CategoryLabelPositions.DOWN_45);
	    
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
	
	private void addToDatasetSeries(XYSeries aTestAppSeries, PerfReportData currRecord, String measurable){
		
		try{
		Integer appLoops=new Integer(currRecord.getNumOfAppLoops());
		Integer avgRespTime=new Integer(Integer.parseInt(currRecord.getAvgResponseTime()));
		Integer ninetyTime=new Integer(Integer.parseInt(currRecord.getNinetyPercentileTime()));
		
		switch (measurable) {
			case AVEGRAGE_RESPONSE_TIME:
				aTestAppSeries.add(appLoops, avgRespTime );
				break;
				
			case PERCENTILE_90_TIME:
				aTestAppSeries.add(appLoops, ninetyTime);
				break;
		}
		}catch (NumberFormatException e) {
			LOG.debug("Number format exception");
			e.printStackTrace();
		}catch (Exception e) {
			LOG.debug("Exception");
			e.printStackTrace();
		}
	}
	
	private List<XYDataset> getXYDataset(List<PerfReportData> reportData, String measurable){
		
		List<XYDataset> dataSetList = new ArrayList<>();
		XYSeriesCollection chartDataset = null;
		XYSeries aTestAppSeries = null;
		PerfReportData prevRecord=null;
		
		for (PerfReportData currRecord : reportData) {
			// first record processing
			if(prevRecord==null){
				chartDataset = new XYSeriesCollection();
				aTestAppSeries = new XYSeries(currRecord.getTestAppName());
				addToDatasetSeries(aTestAppSeries, currRecord, measurable);
			}else{
				if(currRecord.getNumOfUsers()==prevRecord.getNumOfUsers()){
					if(currRecord.getTestAppName().equals(prevRecord.getTestAppName())){
						addToDatasetSeries(aTestAppSeries, currRecord, measurable);
					}else{
						chartDataset.addSeries(aTestAppSeries);
						aTestAppSeries = new XYSeries(currRecord.getTestAppName());
						addToDatasetSeries(aTestAppSeries, currRecord, measurable);
					}
				}else {
					chartDataset.addSeries(aTestAppSeries);
					dataSetList.add(chartDataset);
					chartDataset = new XYSeriesCollection();
					aTestAppSeries = new XYSeries(currRecord.getTestAppName());
					addToDatasetSeries(aTestAppSeries, currRecord, measurable);
				}
			}
			// last record processing
			if(reportData.indexOf(currRecord)==(reportData.size()-1)){
				chartDataset.addSeries(aTestAppSeries);
				dataSetList.add(chartDataset);
			}
			prevRecord = currRecord;
		}
		return dataSetList;
	}
	
	private void createPNGGraphs(List<XYDataset> dataSetList, List<String> users, String measurable){
		
		for (XYDataset lineChartDataset : dataSetList) {
			String numOfUsers = users.get(dataSetList.indexOf(lineChartDataset));
			LOG.info("Creating Multiple Line Graphs for Users: {}", numOfUsers		);
			JFreeChart lineChartObject = null;
			File lineChartPNG = null;
			
			switch (measurable) {
				case AVEGRAGE_RESPONSE_TIME:
					lineChartObject = ChartFactory.createXYLineChart(
				            AVG_RESPONSE_TIME_GRAPH_TITLE + numOfUsers,
				            AVG_RESPONSE_TIME_GRAPH_X_AXIS_TITLE,
				            AVG_RESPONSE_TIME_GRAPH_Y_AXIS_TITLE,
				            lineChartDataset,
				            PlotOrientation.VERTICAL,
				            true,                     
				            true,                     
				            false                     
				        );
				    lineChartPNG = 
				    		new File( AppPerfConfig.AVERAGE_RESPONSE_GRAPH_FILE_NAME + 
				    				  numOfUsers+ 
						              AppPerfConfig.GRAPH_FILE_EXTENTION
						  			);
					break;
				case PERCENTILE_90_TIME:
					lineChartObject = ChartFactory.createXYLineChart(
				            NINETY_PERCENTILE_GRAPH_TITLE + numOfUsers,
				            NINETY_PERCENTILE_GRAPH_X_AXIS_TITLE,
				            NINETY_PERCENTILE_GRAPH_Y_AXIS_TITLE,
				            lineChartDataset,
				            PlotOrientation.VERTICAL,
				            true,                     
				            true,                     
				            false                     
				        );
				    lineChartPNG = 
				    		new File( AppPerfConfig.PERCENTILE_90_GRAPH_FILE_NAME + 
		  				              numOfUsers+ 
		  				              AppPerfConfig.GRAPH_FILE_EXTENTION
		  				             );				
					break;
			}

			XYPlot plot = lineChartObject.getXYPlot();
			XYLineAndShapeRenderer renderer = new XYLineAndShapeRenderer();
			plot.setRenderer(renderer);
			
			for (int i = 0; i < lineChartDataset.getSeriesCount(); i++) {
				// sets paint color for each series
				//	renderer.setSeriesPaint(0, Color.RED);
				// sets thickness for series (using strokes)
				renderer.setSeriesStroke(i, new BasicStroke(2.75f));
			}
				// plot.setOutlinePaint(Color.BLUE);
				// plot.setOutlineStroke(new BasicStroke(2.0f));
				// plot.setBackgroundPaint(Color.DARK_GRAY);
				// plot.setRangeGridlinesVisible(true);
				// plot.setRangeGridlinePaint(Color.BLACK);
				// plot.setDomainGridlinesVisible(true);
				// plot.setDomainGridlinePaint(Color.BLACK);
			
		    int width = AppPerfConfig.GRAPH_CHART_WIDTH;
		    int height = AppPerfConfig.GRAPH_CHART_HEIGHT; 

		    try {
				ChartUtilities.saveChartAsPNG(lineChartPNG ,lineChartObject, width ,height);
			}catch (IOException e) {
				LOG.debug("Exception in file manipulation");
			}
		}
	}
	
	/**
	 * Creates Multiple Line Graphs for the Average Response Time and 90 Percentile Times 
	 * for all the users - hits combinations for all the test urls that are performance tested.
	 * 
	 */
	public void createMultipleLineChart(){

		List<PerfReportData> reportData = PerfTestResultParser.getReportData();
		List<String> users = PerfTestResultParser.getUniqueUsersFromReportData(reportData);
		
		// create Average graphs 
		List<XYDataset> userAvgRespDataSetList = getXYDataset(reportData, AVEGRAGE_RESPONSE_TIME);
		createPNGGraphs(userAvgRespDataSetList, users, AVEGRAGE_RESPONSE_TIME);
		
		// create Percentile Graphs
		List<XYDataset> user90PercDataSetList = getXYDataset(reportData, PERCENTILE_90_TIME);
		createPNGGraphs(user90PercDataSetList, users, PERCENTILE_90_TIME);
	}
}