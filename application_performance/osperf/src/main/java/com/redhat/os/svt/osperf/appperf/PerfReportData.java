package com.redhat.os.svt.osperf.appperf;

public class PerfReportData implements Comparable<PerfReportData>{
	
	private String testPlanName;
	private String avgResponseTime;
	private String ninetyPercentileTime;
	private String totalRequests;
	private String requestErrorPercentage;
	
	// values are set internally based on the test plan name
	private String testAppName;
	private int numOfUsers;
	private int numOfUserLoops;
	private int rampUpTime;
	private int numOfAppLoops;
	private int interval;

	public String getTotalRequests() {
		return totalRequests;
	}
	public void setTotalRequests(String totalRequests) {
		this.totalRequests = totalRequests;
	}
	public String getTestAppName() {
		return testAppName;
	}
	private void setTestAppName(String testAPPName) {
		this.testAppName = testAPPName;
	}
	public int getNumOfUsers() {
		return numOfUsers;
	}
	private void setNumOfUsers(int numOfUsers) {
		this.numOfUsers = numOfUsers;
	}
	public int getNumOfUserLoops() {
		return numOfUserLoops;
	}
	private void setNumOfUserLoops(int numOfUserLoops) {
		this.numOfUserLoops = numOfUserLoops;
	}
	public int getRampUpTime() {
		return rampUpTime;
	}
	private void setRampUpTime(int rampUpTime) {
		this.rampUpTime = rampUpTime;
	}
	public int getNumOfAppLoops() {
		return numOfAppLoops;
	}
	private void setNumOfAppLoops(int numOfAppLoops) {
		this.numOfAppLoops = numOfAppLoops;
	}
	public int getInterval() {
		return interval;
	}
	private void setInterval(int interval) {
		this.interval = interval;
	}
	
	public String getAvgResponseTime() {
		return avgResponseTime;
	}
	public void setAvgResponseTime(String avgResponseTime) {
		this.avgResponseTime = avgResponseTime;
	}
	public String getNinetyPercentileTime() {
		return ninetyPercentileTime;
	}
	public void setNinetyPercentileTime(String ninetyPercentileTime) {
		this.ninetyPercentileTime = ninetyPercentileTime;
	}
	public String getTestPlanName() {
		return testPlanName;
	}
	
	public void setTestPlanName(String testPlanName) {
		this.testPlanName = testPlanName;
		String [] testPlanNameSplits = testPlanName.split(PerfTestPlanCreator.SEPERATOR_IN_TEST_PLAN_NAME);
		setTestAppName(testPlanNameSplits[0]);
		setNumOfUsers(Integer.parseInt(testPlanNameSplits[1]));
		setNumOfUserLoops(Integer.parseInt(testPlanNameSplits[2]));
		setRampUpTime(Integer.parseInt(testPlanNameSplits[3]));
		setNumOfAppLoops(Integer.parseInt(testPlanNameSplits[4]));
		setInterval(Integer.parseInt(testPlanNameSplits[5]));
	}
	
	@Override
	public int hashCode() {
		final int prime = 31;
		int result = 1;
		result = prime * result + ((avgResponseTime == null) ? 0 : avgResponseTime.hashCode());
		result = prime * result + ((ninetyPercentileTime == null) ? 0 : ninetyPercentileTime.hashCode());
		result = prime * result + ((testPlanName == null) ? 0 : testPlanName.hashCode());
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
		if (avgResponseTime == null) {
			if (other.avgResponseTime != null)
				return false;
		} else if (!avgResponseTime.equals(other.avgResponseTime))
			return false;
		if (ninetyPercentileTime == null) {
			if (other.ninetyPercentileTime != null)
				return false;
		} else if (!ninetyPercentileTime.equals(other.ninetyPercentileTime))
			return false;
		if (testPlanName == null) {
			if (other.testPlanName != null)
				return false;
		} else if (!testPlanName.equals(other.testPlanName))
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

		    if(getNumOfUsers() > otherData.getNumOfUsers()){
		    	returnValue = AFTER;
		    }else if(getNumOfUsers() < otherData.getNumOfUsers()){
		    	returnValue = BEFORE;
		    }else{
			    if(getTestPlanName().compareTo(otherData.getTestPlanName())>0){
			    	returnValue = AFTER;
			    }else if(getTestPlanName().compareTo(otherData.getTestPlanName())<0){
			    	returnValue = BEFORE;
			    }else{

			    	if(getNumOfUserLoops() > otherData.getNumOfUserLoops()){
			    		returnValue = AFTER;
			    	}else if(getNumOfUserLoops() < otherData.getNumOfUserLoops()){
			    		returnValue = BEFORE;
			    	}else {
			    		if(getRampUpTime() > otherData.getRampUpTime()){
			    			returnValue = AFTER;
			    		}else if(getRampUpTime() < otherData.getRampUpTime()){
			    			returnValue = BEFORE;
			    		}else {
			    			if(getNumOfAppLoops() > otherData.getNumOfAppLoops()){
			    				returnValue = AFTER;
			    			}else if(getNumOfAppLoops() < otherData.getNumOfAppLoops()){
			    				returnValue = BEFORE;
			    			}else{
			    				if(getInterval() > otherData.getInterval()){
			    					returnValue = AFTER;
			    				}else if(getInterval() < otherData.getInterval()){
			    					returnValue = BEFORE;
			    				}
			    			}
			    		}
			    	  }
        		}
		    }
		return returnValue;
	}
	
	@Override
	public String toString() {
		StringBuffer toString = new StringBuffer();
		toString.append("TestPlanName: "+getTestPlanName()+" ");
		toString.append("avgResponseTime: "+getAvgResponseTime()+" ");
		toString.append("ninetyPercentileTime: "+getNinetyPercentileTime()+" ");
		toString.append("totalRequests: "+getTotalRequests()+" ");
		toString.append("requestErrorPercentage: "+getRequestErrorPercentage()+" ");
		
		return toString.toString();
	}
	public String getRequestErrorPercentage() {
		return requestErrorPercentage;
	}
	public void setRequestErrorPercentage(String requestErrorPercentage) {
		this.requestErrorPercentage = requestErrorPercentage;
	}
}
