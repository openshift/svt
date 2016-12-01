package com.redhat.os.svt.osperf.appperf;

import java.util.Comparator;

public class PerfReportDataByHits implements Comparator<PerfReportData> {

	@Override
	public int compare(PerfReportData dataOne, PerfReportData dataTwo) {
		final int BEFORE = -1;
	    final int EQUAL = 0;
	    final int AFTER = 1;
	    int returnValue=EQUAL;

	    if(dataOne.getNumOfUsers()==0 || dataTwo.getNumOfUsers()==0){
	    	returnValue = BEFORE;
	    }
	    if (dataOne.getTestAppName().compareTo(dataTwo.getTestAppName())<0){
	    	returnValue= BEFORE;
	    }else if (dataOne.getTestAppName().compareTo(dataTwo.getTestAppName())>0){
	    	returnValue= AFTER;
	    }else{
		    if (dataOne.getNumOfUsers()<dataTwo.getNumOfUsers()){
		    	returnValue= BEFORE;
		    }else if (dataOne.getNumOfUsers()>dataTwo.getNumOfUsers()){
		    	returnValue= AFTER;
		    }else{
		    	if(dataOne.getNumOfAppLoops()<dataTwo.getNumOfAppLoops()){
		    		returnValue= BEFORE;	
		    	}else if(dataOne.getNumOfAppLoops()>dataTwo.getNumOfAppLoops()){
		    		returnValue= AFTER;
		    	}
		    }
	    }
	    return returnValue;
	}
}