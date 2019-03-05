package com.redhat.os.svt.osperf.analyzer;

import java.math.BigDecimal;

public class PerfReportData implements Comparable<PerfReportData>{
	
	private String processName;
	private String testRunName;
	private Long xAxisValue;
	private BigDecimal yAxisValue;

	public String getProcessName() {
		return processName;
	}

	public void setProcessName(String processName) {
		this.processName = processName;
	}

	public String getTestRunName() {
		return testRunName;
	}

	public void setTestRunName(String testRunName) {
		this.testRunName = testRunName;
	}

	public Long getxAxisValue() {
		return xAxisValue;
	}

	public void setxAxisValue(Long xAxisValue) {
		this.xAxisValue = xAxisValue;
	}

	public BigDecimal getyAxisValue() {
		return yAxisValue;
	}

	public void setyAxisValue(BigDecimal yAxisValue) {
		this.yAxisValue = yAxisValue;
	}

	@Override
	public int hashCode() {
		final int prime = 31;
		int result = 1;
		result = prime * result + ((yAxisValue == null) ? 0 : yAxisValue.hashCode());
		result = prime * result + ((xAxisValue == null) ? 0 : xAxisValue.hashCode());
		result = prime * result + ((testRunName == null) ? 0 : testRunName.hashCode());
		return result;
	}
	
	@Override
	public boolean equals(Object obj) {
		if (this == obj)
			return true;
		if (obj == null)
			return false;
		if (getClass() != obj.getClass())
			return false;
		PerfReportData other = (PerfReportData) obj;
		if (yAxisValue == null) {
			if (other.yAxisValue != null)
				return false;
		} else if (!yAxisValue.equals(other.yAxisValue))
			return false;
		if (xAxisValue == null) {
			if (other.xAxisValue != null)
				return false;
		} else if (!xAxisValue.equals(other.xAxisValue))
			return false;
		if (testRunName == null) {
			if (other.testRunName != null)
				return false;
		} else if (!testRunName.equals(other.testRunName))
			return false;


		return true;
	}
	
	@Override
	public int compareTo(PerfReportData otherData) {
		final int BEFORE = -1;
	    final int EQUAL = 0;
	    final int AFTER = 1;

	    int returnValue=0;
	    //this optimization is usually worthwhile, and can
	    //always be added
	    if (this == otherData) return EQUAL;

		    if(getyAxisValue().compareTo(otherData.getyAxisValue())>0){
		    	returnValue = AFTER;
		    }else if(getyAxisValue().compareTo(otherData.getyAxisValue())<0){
		    	returnValue = BEFORE;
		    }else{
			    if(getxAxisValue().compareTo(otherData.getxAxisValue())>0){
			    	returnValue = AFTER;
			    }else if(getxAxisValue().compareTo(otherData.getxAxisValue())<0){
			    	returnValue = BEFORE;
			    }else{

			    	if(getTestRunName().compareTo(otherData.getTestRunName())>0){
			    		returnValue = AFTER;
			    	}else if(getTestRunName().compareTo(otherData.getTestRunName())>0){
			    		returnValue = BEFORE;
			    	}
        		}
		    }
		return returnValue;
	}
	
	@Override
	public String toString() {
		StringBuffer toString = new StringBuffer();
		toString.append("testRun: "+getTestRunName()+" ");
		toString.append("CPU Usage Percent: "+getyAxisValue()+" ");
		toString.append("Memory Usage Percent: "+getxAxisValue()+" ");
		
		return toString.toString();
	}
}