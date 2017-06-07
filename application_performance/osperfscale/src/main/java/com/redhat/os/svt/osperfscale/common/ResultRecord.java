package com.redhat.os.svt.osperfscale.common;

import org.apache.commons.csv.CSVRecord;

public class ResultRecord {
	
	private long requestStartTime;
	private long responseTime;
	private short httpResponseCode;
	private int httpRequestLength;
	private int httpResponseLenth;
	private String httpMethod;
	private String httpURL;
	private short threadId;
	private short connectionId;
	private short noOfConnections;
	private short noOfRequests;
	private long connectionStartTime;
	private long socketReadyTime;
	private long connectionTime;
	private String errorMessage;

	public long getRequestStartTime() {
		return requestStartTime;
	}
	public void setRequestStartTime(long requestStartTime) {
		this.requestStartTime = requestStartTime;
	}
	public long getResponseTime() {
		return responseTime;
	}
	public void setResponseTime(long responseTime) {
		this.responseTime = responseTime;
	}
	public short getHttpResponseCode() {
		return httpResponseCode;
	}
	public void setHttpResponseCode(short httpResponseCode) {
		this.httpResponseCode = httpResponseCode;
	}
	public int getHttpRequestLength() {
		return httpRequestLength;
	}
	public void setHttpRequestLength(int httpRequestLength) {
		this.httpRequestLength = httpRequestLength;
	}
	public int getHttpResponseLenth() {
		return httpResponseLenth;
	}
	public void setHttpResponseLenth(int httpResponseLenth) {
		this.httpResponseLenth = httpResponseLenth;
	}
	public String getHttpURL() {
		return httpURL;
	}
	public void setHttpURL(String httpURL) {
		this.httpURL = httpURL;
	}
	public String getHttpMethod() {
		return httpMethod;
	}
	public void setHttpMethod(String httpMethod) {
		this.httpMethod = httpMethod;
	}
	public short getThreadId() {
		return threadId;
	}
	public void setThreadId(short threadId) {
		this.threadId = threadId;
	}
	public short getConnectionId() {
		return connectionId;
	}
	public void setConnectionId(short connectionId) {
		this.connectionId = connectionId;
	}
	public short getNoOfConnections() {
		return noOfConnections;
	}
	public void setNoOfConnections(short noOfConnections) {
		this.noOfConnections = noOfConnections;
	}
	public short getNoOfRequests() {
		return noOfRequests;
	}
	public void setNoOfRequests(short noOfRequests) {
		this.noOfRequests = noOfRequests;
	}
	public long getConnectionStartTime() {
		return connectionStartTime;
	}
	public void setConnectionStartTime(long connectionStartTime) {
		this.connectionStartTime = connectionStartTime;
	}
	public long getSocketReadyTime() {
		return socketReadyTime;
	}
	public void setSocketReadyTime(long socketReadyTime) {
		this.socketReadyTime = socketReadyTime;
	}
	public long getConnectionTime() {
		return connectionTime;
	}
	public void setConnectionTime(long connectionTime) {
		this.connectionTime = connectionTime;
	}
	public String getErrorMessage() {
		return errorMessage;
	}
	public void setErrorMessage(String errorMessage) {
		this.errorMessage = errorMessage;
	}
	
	public static ResultRecord convertToResultRecord(CSVRecord csvRecord){
		ResultRecord returnRecord = new ResultRecord();
		
		returnRecord.requestStartTime = Long.parseLong(csvRecord.get(CSVHeader.REQUEST_START_TIME));
		returnRecord.responseTime = (Long.parseLong(csvRecord.get(CSVHeader.RESPONSE_TIME)))/1000;
		returnRecord.httpResponseCode = Short.parseShort(csvRecord.get(CSVHeader.HTTP_RESPONSE_CODE));
		returnRecord.httpRequestLength = Integer.parseInt(csvRecord.get(CSVHeader.HTTP_REQUEST_LENGTH));
		returnRecord.httpResponseLenth = Integer.parseInt(csvRecord.get(CSVHeader.HTTP_RESPONSE_LENGTH));
		returnRecord.threadId = Short.parseShort(csvRecord.get(CSVHeader.THREAD_ID));
		returnRecord.connectionId = Short.parseShort(csvRecord.get(CSVHeader.CONNECTION_ID));
		returnRecord.noOfConnections = Short.parseShort(csvRecord.get(CSVHeader.NO_OF_CONNECTIONS));
		returnRecord.noOfRequests =  Short.parseShort(csvRecord.get(CSVHeader.NO_OF_HTTP_REQUESTS));
		returnRecord.connectionStartTime = Long.parseLong(csvRecord.get(CSVHeader.CONNECTION_START_TIME));
		returnRecord.socketReadyTime =  Long.parseLong(csvRecord.get(CSVHeader.SOCKET_READY_TIME));
	    returnRecord.connectionTime = Long.parseLong(csvRecord.get(CSVHeader.CONNECTION_TIME));
		returnRecord.errorMessage = csvRecord.get(CSVHeader.ERROR_MESSAGE);
		
		// GET http://URL:80/
		String methodAndURL = csvRecord.get(CSVHeader.HTTP_METHOD_AND_URL);
		String [] methodAndURLSplits = methodAndURL.split(" ");
		returnRecord.httpMethod = methodAndURLSplits[0].trim();
		returnRecord.httpURL = ((methodAndURLSplits[1].split("/"))[2].split(":"))[0];
		
		return returnRecord;
	}
}