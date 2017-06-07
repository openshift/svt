package com.redhat.os.svt.osperfscale.utils;

import java.awt.BasicStroke;
import java.io.File;
import java.io.IOException;
import java.util.List;
import java.util.Map;

import org.jfree.chart.ChartFactory;
import org.jfree.chart.ChartUtilities;
import org.jfree.chart.JFreeChart;
import org.jfree.chart.plot.PlotOrientation;
import org.jfree.chart.plot.XYPlot;
import org.jfree.chart.renderer.xy.XYLineAndShapeRenderer;
import org.jfree.data.category.DefaultCategoryDataset;
import org.jfree.data.xy.XYDataset;
import org.jfree.data.xy.XYSeries;
import org.jfree.data.xy.XYSeriesCollection;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.redhat.os.svt.osperfscale.common.AppConstants;
import com.redhat.os.svt.osperfscale.common.ResultObject;

/**
 * Creates graphs for the test results gathered from the perf test runs.
 * 
 * @author schituku
 *
 */
public class GraphCreator3D {

	protected static final String RESPONSE_TIME_GRAPH_TITLE = "RESPONSE TIME vs APP HITS";
	protected static final String RESPONSE_TIME_GRAPH_TITLE_FOR_APPS = "APP NAME: ";
	protected static final String RESPONSE_TIME_GRAPH_X_AXIS_TITLE = "HitNumber";
	protected static final String RESPONSE_TIME_GRAPH_X_AXIS_TITLE_FOR_APPS = "Number of Users";
	protected static final String RESPONSE_TIME_GRAPH_Y_AXIS_TITLE = "ResponseTime(ms)";
	
	protected static final String RESPONSE_BAR_GRAPH_TITLE = "RESPONSE TIMES FOR APPS ";
	protected static final String RESPONSE_BAR_GRAPH_TITLE_FOR_APPS = "APP NAME: ";
	protected static final String RESPONSE_BAR_GRAPH_X_AXIS_TITLE = "App Name";
	protected static final String RESPONSE_BAR_GRAPH_X_AXIS_TITLE_FOR_APPS = "Number of Users";
	protected static final String RESPONSE_BAR_GRAPH_Y_AXIS_TITLE = "ResponseTime(ms)";

	protected static final String AVG_RESPONSE_TIME_GRAPH_TITLE = "AVG RESPONSE TIMES OF APPS ";
	protected static final String AVG_RESPONSE_TIME_GRAPH_TITLE_FOR_APPS = "APP NAME: ";
	protected static final String AVG_RESPONSE_TIME_GRAPH_X_AXIS_TITLE = "App Name";
	protected static final String AVG_RESPONSE_TIME_GRAPH_X_AXIS_TITLE_FOR_APPS = "Number of Users";
	protected static final String AVG_RESPONSE_TIME_GRAPH_Y_AXIS_TITLE = "AvgTime(ms)";

	protected static final String NINETY_PERCENTILE_GRAPH_TITLE = "NUMBER OF USERS - ";
	protected static final String NINETY_PERCENTILE_GRAPH_TITLE_FOR_APPS = "APP NAME: ";
	protected static final String NINETY_PERCENTILE_GRAPH_X_AXIS_TITLE = "App Number";
	protected static final String NINETY_PERCENTILE_GRAPH_X_AXIS_TITLE_FOR_APPS = "Number of Users";
	protected static final String NINETY_PERCENTILE_GRAPH_Y_AXIS_TITLE = "90PercentileTime(ms)";

	protected final Logger LOG = LoggerFactory.getLogger(GraphCreator3D.class);

	private void createPNGGraphs(XYDataset lineChartDataset, String graphHeader, String xAxisTitle, String yAxisTitle,
			String graphFileName) {

		LOG.info("Creating Multiple Line Graphs");
		JFreeChart lineChartObject = null;
		File lineChartPNG = null;

		lineChartObject = ChartFactory.createXYLineChart(graphHeader, xAxisTitle, yAxisTitle, lineChartDataset,
				PlotOrientation.VERTICAL, true, true, false);
		lineChartPNG = new File(graphFileName + AppConstants.GRAPH_FILE_EXTENTION);

		XYPlot plot = lineChartObject.getXYPlot();
		XYLineAndShapeRenderer renderer = new XYLineAndShapeRenderer();
		plot.setRenderer(renderer);

		for (int i = 0; i < lineChartDataset.getSeriesCount(); i++) {
			// sets paint color for each series
			// renderer.setSeriesPaint(0, Color.RED);
			// sets thickness for series (using strokes)
			renderer.setSeriesStroke(i, new BasicStroke(2.0f));
		}
		// plot.setOutlinePaint(Color.BLUE);
		// plot.setOutlineStroke(new BasicStroke(2.0f));
		// plot.setBackgroundPaint(Color.DARK_GRAY);
		// plot.setRangeGridlinesVisible(true);
		// plot.setRangeGridlinePaint(Color.BLACK);
		// plot.setDomainGridlinesVisible(true);
		// plot.setDomainGridlinePaint(Color.BLACK);

		int width = AppConstants.GRAPH_CHART_WIDTH;
		int height = AppConstants.GRAPH_CHART_HEIGHT;

		try {
			ChartUtilities.saveChartAsPNG(lineChartPNG, lineChartObject, width, height);
		} catch (IOException e) {
			LOG.debug("Exception in file manipulation");
		}

	}

	private void createBarChartPNGGraphs(DefaultCategoryDataset categoryDataset, 
			String graphHeader, String xAxisTitle, String yAxisTitle,
			String graphFileName) {

		LOG.info("Creating Bar chart Graphs");
		JFreeChart barChartObject = null;
		File barChartPNG = null;

		barChartObject = ChartFactory.createBarChart(graphHeader, xAxisTitle, yAxisTitle, categoryDataset,
				PlotOrientation.VERTICAL, true, true, false);
		barChartPNG = new File(graphFileName + AppConstants.GRAPH_FILE_EXTENTION);

//		XYPlot plot = barChartObject.getXYPlot();
//		XYLineAndShapeRenderer renderer = new XYLineAndShapeRenderer();
//		plot.setRenderer(renderer);
//
//		for (int i = 0; i < lineChartDataset.getSeriesCount(); i++) {
//			// sets paint color for each series
//			// renderer.setSeriesPaint(0, Color.RED);
//			// sets thickness for series (using strokes)
//			renderer.setSeriesStroke(i, new BasicStroke(2.0f));
//		}
		// plot.setOutlinePaint(Color.BLUE);
		// plot.setOutlineStroke(new BasicStroke(2.0f));
		// plot.setBackgroundPaint(Color.DARK_GRAY);
		// plot.setRangeGridlinesVisible(true);
		// plot.setRangeGridlinePaint(Color.BLACK);
		// plot.setDomainGridlinesVisible(true);
		// plot.setDomainGridlinePaint(Color.BLACK);

		int width = AppConstants.GRAPH_CHART_WIDTH;
		int height = AppConstants.GRAPH_CHART_HEIGHT;

		try {
			ChartUtilities.saveChartAsPNG(barChartPNG, barChartObject, width, height);
		} catch (IOException e) {
			LOG.debug("Exception in file manipulation");
		}

	}

	public void createResponseLineChart(Map<String, ResultObject> resultsMap) {
		// create Average graphs
		XYDataset lineChartDataset = getResponseLineChartDataset(resultsMap);
		createPNGGraphs(lineChartDataset, RESPONSE_TIME_GRAPH_TITLE, RESPONSE_TIME_GRAPH_X_AXIS_TITLE,
				RESPONSE_TIME_GRAPH_Y_AXIS_TITLE, AppConstants.RESPONSE_GRAPH_FILE_NAME);
	}

	private XYDataset getResponseLineChartDataset(Map<String, ResultObject> resultsMap) {

		XYSeriesCollection chartDataset = new XYSeriesCollection();
		XYSeries aTestAppSeries = null;
		List<Long> responseTimes;
		// Integer app=new Integer(0);
		Integer hitcount;
		for (Map.Entry<String, ResultObject> entry : resultsMap.entrySet()) {

			aTestAppSeries = new XYSeries(entry.getValue().getTestName());
			responseTimes = entry.getValue().getResponseTimes();
			hitcount = new Integer(0);
			for (Long responseTime : responseTimes) {
				hitcount = new Integer(hitcount.intValue() + 1);
				aTestAppSeries.add(hitcount, responseTime);
				// if(responseTime.longValue()<100 ||
				// responseTime.longValue()>50000)
				// LOG.debug("The response time is: "+responseTime);
			}
			chartDataset.addSeries(aTestAppSeries);
		}
		return chartDataset;
	}

	public void createAvgResponseLineChart(Map<String, ResultObject> resultsMap) {
		// create Average graphs
		XYDataset lineChartDataset = getAvgLineChartDataset(resultsMap);
		createPNGGraphs(lineChartDataset, AVG_RESPONSE_TIME_GRAPH_TITLE, AVG_RESPONSE_TIME_GRAPH_X_AXIS_TITLE,
				AVG_RESPONSE_TIME_GRAPH_Y_AXIS_TITLE, AppConstants.AVERAGE_RESPONSE_GRAPH_FILE_NAME);
	}

	private XYDataset getAvgLineChartDataset(Map<String, ResultObject> resultsMap) {

		XYSeriesCollection chartDataset = new XYSeriesCollection();
		XYSeries aTestAppSeries = new XYSeries("AvgResponseLine");
		 Integer app = new Integer(0);
		for (Map.Entry<String, ResultObject> entry : resultsMap.entrySet()) {
			app = new Integer(app.intValue()+1);
			aTestAppSeries.add(app,
					new Integer((int) entry.getValue().getResponseStats().getGeometricMean()));
			// if(responseTime.longValue()<100 ||
			// responseTime.longValue()>50000)
			// LOG.debug("The response time is: "+responseTime);
		}
		chartDataset.addSeries(aTestAppSeries);
		return chartDataset;
	}

	public void createNinetyPercentileLineChart(Map<String, ResultObject> resultsMap) {
		// create Average graphs
		XYDataset lineChartDataset = getNinetyPercentileChartDataset(resultsMap);
		createPNGGraphs(lineChartDataset, NINETY_PERCENTILE_GRAPH_TITLE, NINETY_PERCENTILE_GRAPH_X_AXIS_TITLE,
				NINETY_PERCENTILE_GRAPH_Y_AXIS_TITLE, AppConstants.PERCENTILE_90_GRAPH_FILE_NAME);
	}

	private XYDataset getNinetyPercentileChartDataset(Map<String, ResultObject> resultsMap) {

		XYSeriesCollection chartDataset = new XYSeriesCollection();
		XYSeries aTestAppSeries = new XYSeries("90PercentileResponseLine");
		Integer app = new Integer(0);
		for (Map.Entry<String, ResultObject> entry : resultsMap.entrySet()) {
			app = new Integer(app.intValue() + 1);
			aTestAppSeries.add(app, new Integer((int) entry.getValue().getResponseStats().getPercentile(90.00)));
			// if(responseTime.longValue()<100 ||
			// responseTime.longValue()>50000)
			// LOG.debug("The response time is: "+responseTime);
		}
		chartDataset.addSeries(aTestAppSeries);
		return chartDataset;
	}
	public void createResponseBarChart(Map<String, ResultObject> resultsMap) {
		// create bar chart for Average and 90 percentile
		DefaultCategoryDataset barChartDataset = getBarChartDataset(resultsMap);
		createBarChartPNGGraphs(barChartDataset, RESPONSE_BAR_GRAPH_TITLE, RESPONSE_BAR_GRAPH_X_AXIS_TITLE,
				RESPONSE_BAR_GRAPH_Y_AXIS_TITLE, AppConstants.RESPONSE_BAR_GRAPH_FILE_NAME);
	}
	private DefaultCategoryDataset getBarChartDataset(Map<String, ResultObject> resultsMap) {

		DefaultCategoryDataset barChartDataSet = new DefaultCategoryDataset();
		for (Map.Entry<String, ResultObject> entry : resultsMap.entrySet()) {
			barChartDataSet.addValue(new Integer((int) entry.getValue().getResponseStats().getGeometricMean()), 
					entry.getValue().getTestName(), AVG_RESPONSE_TIME_GRAPH_Y_AXIS_TITLE);
			barChartDataSet.addValue(new Integer((int) entry.getValue().getResponseStats().getPercentile(90.00)), 
					entry.getValue().getTestName(), NINETY_PERCENTILE_GRAPH_Y_AXIS_TITLE);
		}
		return barChartDataSet;
	}
}