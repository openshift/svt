package com.redhat.os.svt.osperf.analyzer;

public class PerfTestParameter{
	
	long [] numberOfUsers;
	long [] rampUpTime;
	long [] numberOfUserLoops;
	long [] numberOfAppLoops;
	String appURL;
	long [] intervalBetweenAppHits;
	String testSuiteName;
	
	public long[] getNumberOfUsers() {
		return numberOfUsers;
	}
	public void setNumberOfUsers(long[] numberOfUsers) {
		this.numberOfUsers = numberOfUsers;
	}
	public long[] getRampUpTime() {
		return rampUpTime;
	}
	public void setRampUpTime(long[] rampUpTime) {
		this.rampUpTime = rampUpTime;
	}
	public long[] getNumberOfUserLoops() {
		return numberOfUserLoops;
	}
	public void setNumberOfUserLoops(long[] numberOfUserLoops) {
		this.numberOfUserLoops = numberOfUserLoops;
	}
	public long[] getNumberOfAppLoops() {
		return numberOfAppLoops;
	}
	public void setNumberOfAppLoops(long[] numberOfAppLoops) {
		this.numberOfAppLoops = numberOfAppLoops;
	}
	public String getAppURL() {
		return appURL;
	}
	public void setAppURL(String appURL) {
		this.appURL = appURL;
	}
	public long[] getIntervalBetweenAppHits() {
		return intervalBetweenAppHits;
	}
	public void setIntervalBetweenAppHits(long[] intervalBetweenAppHits) {
		this.intervalBetweenAppHits = intervalBetweenAppHits;
	}
	public String getTestSuiteName() {
		return testSuiteName;
	}
	public void setTestSuiteName(String testSuiteName) {
		this.testSuiteName = testSuiteName;
	}
}