package com.redhat.os.svt.osperf.analyzer.support.configuration;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.nio.charset.CharsetDecoder;
import java.nio.charset.CodingErrorAction;

import org.apache.commons.io.Charsets;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.yaml.snakeyaml.Yaml;

/**
 * An Yaml Parser that parses a given yaml file on the classpath into an object of parameter type.
 * @author schituku
 *
 */
public class ConfigYamlParser{

	private static final Logger LOG = LoggerFactory.getLogger(ConfigYamlParser.class);
	
	/**
	 * This method will parse a yaml file into an object of the this class parameter type.
	 * The yaml file has to be on the classpath.
	 * 
	 * @param yamlFileName
	 * @return parsed object of the parameter type of this class
	 * @throws IOException
	 */
	public TestConfig  parseYaml(String yamlFileName) throws Exception {
		//TODO add custom exceptions to return for mal-formed yaml file.
		LOG.debug("Parsing the yaml file: {}", yamlFileName);
		Reader reader = readScenarioYamlAndIgnoreUnwantedChars(yamlFileName);
		TestConfig testConfig = new Yaml().loadAs(reader, TestConfig.class);
		validateYaml(testConfig);
		return testConfig;
		
	}

	private Reader readScenarioYamlAndIgnoreUnwantedChars(String yamlFileName) throws IOException {
		InputStream is = 
				Thread.currentThread().getContextClassLoader().getResourceAsStream(yamlFileName);
		LOG.debug("got the input stream");
		CharsetDecoder decoder = Charsets.UTF_8.newDecoder();
		decoder.onMalformedInput(CodingErrorAction.IGNORE);
		Reader reader = new InputStreamReader(is, decoder);
		LOG.debug("Returning the reader");
		return reader;
	}
	private void validateYaml(TestConfig testConfig){
		//TODO error check the yaml for the correct syntax
		// numbers and URL syntax etc.
		// add custom exceptions for returning.
		LOG.debug("in validate method");
	}
}