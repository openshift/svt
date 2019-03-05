package com.redhat.os.svt.osperf.analyzer.support.charts;

import java.awt.BasicStroke;
import java.io.File;
import java.io.IOException;
import java.util.List;

import org.jfree.chart.ChartFactory;
import org.jfree.chart.ChartUtilities;
import org.jfree.chart.JFreeChart;
import org.jfree.chart.plot.PlotOrientation;
import org.jfree.chart.plot.XYPlot;
import org.jfree.chart.renderer.xy.XYLineAndShapeRenderer;
import org.jfree.data.xy.XYDataset;
import org.jfree.data.xy.XYSeries;
import org.jfree.data.xy.XYSeriesCollection;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.redhat.os.svt.osperf.analyzer.PerfReportData;
import com.redhat.os.svt.osperf.analyzer.support.configuration.AppPerfConfig;
import com.redhat.os.svt.osperf.parser.PerfTestResultParser;

public class GraphCreator {
	
	protected final Logger LOG = LoggerFactory.getLogger(GraphCreator.class);
	
	public void createATestRunGraph(String processName, String measurable) {
		
		List<PerfReportData> reportData = PerfTestResultParser.getReportData(processName, measurable);
		
		if (reportData==null || reportData.isEmpty()) {
			LOG.debug("No report data and hence skipping drawing the graph for "+processName+"-"+measurable);
		}else {
			// create graph 
			XYDataset reportDataSet = getXYDataset(reportData);
			String graphTitle = processName+"-"+measurable;
			createPNGGraphs(reportDataSet, graphTitle, AppPerfConfig.GRAPH_X_AXIS_TITLE.get(processName), measurable);
		}
	}
	
	private XYDataset getXYDataset(List<PerfReportData> reportData){
		
		XYSeriesCollection chartDataset = null;
		XYSeries aTestRunSeries = null;
		PerfReportData prevRecord=null;
		
		for (PerfReportData currRecord : reportData) {
			// first record processing
			if(prevRecord==null){
				chartDataset = new XYSeriesCollection();
				aTestRunSeries = new XYSeries(currRecord.getTestRunName());
				aTestRunSeries.add(currRecord.getxAxisValue(), currRecord.getyAxisValue() );
			}else{
				if(currRecord.getTestRunName().equals(prevRecord.getTestRunName())){
					aTestRunSeries.add(currRecord.getxAxisValue(), currRecord.getyAxisValue() );
				}else{
					chartDataset.addSeries(aTestRunSeries);
					aTestRunSeries = new XYSeries(currRecord.getTestRunName());
					aTestRunSeries.add(currRecord.getxAxisValue(), currRecord.getyAxisValue() );
				}
			}
			// last record processing
			if(reportData.indexOf(currRecord)==(reportData.size()-1)){
				chartDataset.addSeries(aTestRunSeries);
			}
			prevRecord = currRecord;
		}
		return chartDataset;
	}
	
	private void createPNGGraphs(XYDataset lineChartDataset, String graphTitle, String xAxisTitle, String yAxisTitle){
		
		LOG.info("Creating Multiple Line Graphs for TestRun: {}", graphTitle);
		JFreeChart lineChartObject = null;
		File lineChartPNG = null;
		
		lineChartObject = ChartFactory.createXYLineChart(
		            graphTitle,
		            xAxisTitle,
		            yAxisTitle,
		            lineChartDataset,
		            PlotOrientation.VERTICAL,
		            true,                     
		            true,                     
		            false                     
		        );
	    lineChartPNG = 
		    		new File( AppPerfConfig.BASE_GRAPH_FILE_NAME+"-"+graphTitle+ 
				              AppPerfConfig.GRAPH_FILE_EXTENTION
				  			);

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
