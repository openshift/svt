package com.redhat.os.svt.workloads.domain;

import java.util.Objects;

public class TestResultObject implements Comparable<TestResultObject>{

    private String testCombination;
    private String testName;
    private String requests;


    public TestResultObject(String testCombination, String testName, String requests) {
        this.testCombination = testCombination;
        this.testName = testName;
        this.requests = requests;
    }

    public String getTestCombination() {
        return testCombination;
    }

    public void setTestCombination(String testCombination) {
        this.testCombination = testCombination;
    }

    public String getTestName() {
        return testName;
    }

    public void setTestName(String testName) {
        this.testName = testName;
    }

    public String getRequests() {
        return requests;
    }

    public void setRequests(String requests) {
        this.requests = requests;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof TestResultObject)) return false;
        TestResultObject that = (TestResultObject) o;
        return Objects.equals(getTestCombination(), that.getTestCombination()) &&
                Objects.equals(getTestName(), that.getTestName()) &&
                Objects.equals(getRequests(), that.getRequests());
    }

    @Override
    public int hashCode() {
        return Objects.hash(getTestCombination(), getTestName(), getRequests());
    }

    @Override
    public int compareTo(TestResultObject otherData) {
        final int BEFORE = -1;
        final int EQUAL = 0;
        final int AFTER = 1;

        int returnValue;
        //this optimization is usually worthwhile, and can
        //always be added
        if (this == otherData) return EQUAL;

        if(getTestCombination().compareTo(otherData.getTestCombination())>0){
            returnValue = AFTER;
        }else if(getTestCombination().compareTo(otherData.getTestCombination())<0){
            returnValue = BEFORE;
        }else{
            if(getTestName().compareTo(otherData.getTestName())>0){
                returnValue = AFTER;
            }else if(getTestName().compareTo(otherData.getTestName())<0){
                returnValue = BEFORE;
            }else{
                returnValue = EQUAL;
            }
        }
        return returnValue;
    }

    @Override
    public String toString() {
        StringBuffer toString = new StringBuffer();
        toString.append(getTestCombination());
        toString.append(","+getTestName()+",");
        toString.append(getRequests());

        return toString.toString();
    }
}