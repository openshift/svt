package com.redhat.os.svt.osperf.appperf;


import java.io.File;
import java.io.FileOutputStream;
import java.net.URL;

import org.apache.jmeter.control.gui.TestPlanGui;
import org.apache.jmeter.save.SaveService;
import org.apache.jmeter.testelement.TestElement;
import org.apache.jmeter.testelement.TestPlan;
import org.apache.jmeter.threads.ThreadGroup;
import org.apache.jmeter.util.JMeterUtils;
import org.apache.jorphan.collections.HashTree;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
public class PerfTestPlan {
	
	public static final String JMETER_PROPERTIES = "jmeter.properties" ;
	private static final Logger LOG = LoggerFactory.getLogger(PerfTestPlan.class);	

    public File createTestPlan()  throws Exception {
    	
    	// Initialize the configuration variables
    	URL url = Thread.currentThread().getContextClassLoader().getResource(JMETER_PROPERTIES);
    	if( url == null ){
    	    throw new RuntimeException( "Cannot find resource on classpath");
    	}
    	
    	String file = url.getFile();
    	LOG.debug("The file path is: {}",file);
    	JMeterUtils.setJMeterHome(new File(url.getPath()).getParent());
        JMeterUtils.loadJMeterProperties(file);
        JMeterUtils.initLogging();
        JMeterUtils.initLocale();
        
        SaveService.loadProperties();

     // Create TestPlan hash tree
        HashTree mainHashTree = new HashTree();

        // TestPlan
        TestPlan testPlan = new TestPlan();
        testPlan.setName("TestPlan");
        testPlan.setEnabled(true);
        testPlan.setProperty(TestElement.TEST_CLASS, TestPlan.class.getName());
        testPlan.setProperty(TestElement.GUI_CLASS, TestPlanGui.class.getName());
        
        // create Thread Group Hash Tree
        
        HashTree threadGroupHashTree = new HashTree();

        // ThreadGroup
        ThreadGroup threadGroup = new ThreadGroup();
        threadGroup.setEnabled(true);
//        threadGroup.setSamplerController(loopController);
        threadGroup.setNumThreads(1);
        threadGroup.setRampUp(1);
        threadGroup.setProperty(TestElement.TEST_CLASS, "ThreadGroup");
        threadGroup.setProperty(TestElement.GUI_CLASS, "ThreadGroupGui");
        threadGroup.setThreadName("AppTest");
        
        threadGroupHashTree.add(threadGroup);

//        // ThreadGroup controller
//        LoopController loopController = new LoopController();
//        loopController.setEnabled(true);
//        loopController.setLoops(5);
//        loopController.setProperty(TestElement.TEST_CLASS, LoopController.class.getName());
//        loopController.setProperty(TestElement.GUI_CLASS, LoopControlPanel.class.getName());
//        
//     // HTTP Sampler
//        HTTPSampler httpSampler = new HTTPSampler();
//        httpSampler.setName("httpsampler");
//        httpSampler.setEnabled(true);
//        httpSampler.setProperty(TestElement.TEST_CLASS, ThreadGroup.class.getName());
//        httpSampler.setProperty(TestElement.GUI_CLASS, ThreadGroupGui.class.getName());        
//        httpSampler.setDomain("example.com");
////        httpSampler.setPort(80);
//        httpSampler.setPath("/");
//        httpSampler.setMethod("GET");
//        
//        
//        

        mainHashTree.add(testPlan);
        mainHashTree.add(threadGroupHashTree);
        

        File testPlanFile = new File("test.jmx");
        // Save to jmx file
        SaveService.saveTree(mainHashTree, new FileOutputStream(testPlanFile));
        return testPlanFile;
        }
}