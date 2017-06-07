package com.redhat.os.svt.osperfscale.common;

import com.google.gson.annotations.SerializedName;

public class RequestObject {
	
	@SerializedName("host_from")
	private String hostFrom; 
	private String scheme;
	@SerializedName("tls-session-reuse")
	private boolean tlsSessionReuse;
	private String host; 
	private String port; 
	private String method; 
	private String path; 
//	headers: an array of custom HTTP headers
//	body: HTTP requests body
//	max-requests: how many HTTP requests to send to host in total. If the value is 0 or unspecified, the requests will be sent for the entire duration of the test. If there is no more HTTP requests to be sent for all hosts, the test may finish earlier than specified.
//	keep-alive-requests: how many HTTP requests to send within a single TCP connection, including the last "Connection: close" request. If the value is 0 or unspecified, the "Connection: close" will never be sent.
	private int clients; 
	private DelayObject delay;
	@SerializedName("ramp-up")
	private int rampUp;

	public String getScheme() {
		return scheme;
	}
	public void setScheme(String scheme) {
		this.scheme = scheme;
	}
	public boolean isTlsSessionReuse() {
		return tlsSessionReuse;
	}
	public void setTlsSessionReuse(boolean tlsSessionReuse) {
		this.tlsSessionReuse = tlsSessionReuse;
	}
	public String getHost() {
		return host;
	}
	public void setHost(String host) {
		this.host = host;
	}
	public String getPort() {
		return port;
	}
	public void setPort(String port) {
		this.port = port;
	}
	public String getMethod() {
		return method;
	}
	public void setMethod(String method) {
		this.method = method;
	}
	public String getPath() {
		return path;
	}
	public void setPath(String path) {
		this.path = path;
	}
	public int getClients() {
		return clients;
	}
	public void setClients(int clients) {
		this.clients = clients;
	}
	public DelayObject getDelay() {
		return delay;
	}
	public void setDelay(DelayObject delay) {
		this.delay = delay;
	}
	public int getRampUp() {
		return rampUp;
	}
	public void setRampUp(int rampUp) {
		this.rampUp = rampUp;
	}
	public String getHostFrom() {
		return hostFrom;
	}
	public void setHostFrom(String hostFrom) {
		this.hostFrom = hostFrom;
	}
}