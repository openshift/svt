package com.redhat.os.svt.workloads.parser;

import com.redhat.os.svt.workloads.analyzer.support.configuration.WorkloadAnalyzerConfig;
import com.redhat.os.svt.workloads.domain.TestResultObject;
import org.apache.commons.io.FileUtils;
import org.apache.commons.io.filefilter.DirectoryFileFilter;
import org.apache.commons.io.filefilter.TrueFileFilter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class WorkloadParser {

    private static final Logger LOG = LoggerFactory.getLogger(WorkloadParser.class);

    public void downloadReport(String url) throws IOException {

        LOG.info("Trying to download the file:"+url);
        String tempDownloadFileName = "tempDownload.tar.xz";
        File downloadedReport = new File(WorkloadAnalyzerConfig.TEST_INPUT_FILES_DIRECTORY+tempDownloadFileName);

        FileUtils.copyURLToFile(new URL(url), downloadedReport, 1000, 1000);

        String pathOfInputDirectory = downloadedReport.getParentFile().getAbsolutePath();
        String command = String.format("tar -xvf %s -C %s", WorkloadAnalyzerConfig.TEST_INPUT_FILES_DIRECTORY+tempDownloadFileName, WorkloadAnalyzerConfig.TEST_INPUT_FILES_DIRECTORY);
//        LOG.info(command);
        try {
        Process process;
        process = Runtime.getRuntime().exec(command);

//        BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
//        String line;
//        while ((line = reader.readLine()) != null) {
//            LOG.info(line);
//        }
//        reader.close();

//        BufferedReader errorReader = new BufferedReader(
//                    new InputStreamReader(process.getErrorStream()));
//        while ((line = errorReader.readLine()) != null) {
//              System.out.println(line);
//        }
//
//        errorReader.close();
        int exitValue = process.waitFor();
        if (exitValue != 0) {
                LOG.info("Abnormal process termination");
        }
        process.destroy();

        FileUtils.forceDelete(downloadedReport);
        LOG.info("Finished downloading the file:"+url);
        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
            LOG.info("Error downloading the file:"+url);
        }
    }

    public void getReport() {
        Collection<File> reportFiles = FileUtils.listFilesAndDirs(new File(WorkloadAnalyzerConfig.TEST_INPUT_FILES_DIRECTORY),
                TrueFileFilter.INSTANCE, DirectoryFileFilter.DIRECTORY);

        Map<String,Map<String, Map<String, Map<String, String>>>> testResultMap = new HashMap<String, Map<String, Map<String, Map<String,String>>>>();
        // testname, noOfTemplates, noOfConnsPerTarget, noOfKeepAlives
        Map<String, String> keepAlivesMap=null;
        Map<String, Map<String,String>> connsPerTargetMap=null;
        Map<String, Map<String, Map<String, String>>> templatesMap = null;

        for (File aFile : reportFiles) {

//            LOG.info("Processing the report File name: {} ", aFile.getName());

            if(aFile.getName().contains("rps")){
                try {
                    String rpsValue = FileUtils.readFileToString(aFile.getAbsoluteFile(), StandardCharsets.UTF_8);
                    LOG.info("The absolute path is: "+ aFile.getPath());
                    String[] keys = aFile.getPath().split("/");
                    String testName =  keys[1].split("-")[keys[1].split("-").length - 1];
                    String noOftemplates = keys[3];
                    String noOfConnsPerTarget= keys[4];;
                    String noOfKeepAlives= keys[5];;

                    LOG.info("The value is: "+ testName);
                    LOG.info("The value is: "+ rpsValue);
                    if(testResultMap.get(testName) == null || testResultMap.get(testName).isEmpty()){
                        keepAlivesMap = new HashMap<String, String>();
                        keepAlivesMap.put(noOfKeepAlives, rpsValue);
                        connsPerTargetMap = new HashMap<String, Map<String, String>>();
                        connsPerTargetMap.put(noOfConnsPerTarget, keepAlivesMap);
                        templatesMap = new HashMap<String, Map<String, Map<String, String>>>();
                        templatesMap.put(noOftemplates, connsPerTargetMap);
                        testResultMap.put(testName, templatesMap);
                    }else {
                        templatesMap = testResultMap.get(testName);
                        if (testResultMap.get(testName).get(noOftemplates) == null || testResultMap.get(testName).get(noOftemplates).isEmpty()) {
                            keepAlivesMap = new HashMap<String, String>();
                            keepAlivesMap.put(noOfKeepAlives, rpsValue);
                            connsPerTargetMap = new HashMap<String, Map<String, String>>();
                            connsPerTargetMap.put(noOfConnsPerTarget, keepAlivesMap);
                            templatesMap.put(noOftemplates, connsPerTargetMap);
                            testResultMap.put(testName, templatesMap);
                        } else {
                            if (testResultMap.get(testName).get(noOftemplates).get(noOfConnsPerTarget) == null ||
                                    testResultMap.get(testName).get(noOftemplates).get(noOfConnsPerTarget).isEmpty()) {
                                keepAlivesMap = new HashMap<String, String>();
                                keepAlivesMap.put(noOfKeepAlives, rpsValue);
                                connsPerTargetMap.put(noOfConnsPerTarget, keepAlivesMap);
                                templatesMap.put(noOftemplates, connsPerTargetMap);
                                testResultMap.put(testName, templatesMap);
                            } else {
                                if (testResultMap.get(testName).get(noOftemplates).get(noOfConnsPerTarget).get(noOfKeepAlives) == null ||
                                        testResultMap.get(testName).get(noOftemplates).get(noOfConnsPerTarget).get(noOfKeepAlives).isEmpty()) {
                                    keepAlivesMap = templatesMap.get(noOftemplates).get(noOfConnsPerTarget);
                                    keepAlivesMap.put(noOfKeepAlives, rpsValue);
                                    connsPerTargetMap.put(noOfConnsPerTarget, keepAlivesMap);
                                    templatesMap.put(noOftemplates, connsPerTargetMap);
                                    testResultMap.put(testName, templatesMap);
                                }
                            }
                        }
                    }


                } catch (IOException e) {
                    e.printStackTrace();
                    LOG.info("Error processing the file: "+aFile.getName());
                }
             }
        }

        String consolidatedResultsFile = WorkloadAnalyzerConfig.CONSOLIDATED_RESULTS_FILE_NAME + WorkloadAnalyzerConfig.CONSOLIDATED_RESULTS_FILE_EXTENTION;
        List<String> consolidatedResultsLines = new ArrayList<String>();
        consolidatedResultsLines.add("TEST-NAME,TEMPLATES,CONNECTIONS,KEEP-ALIVES,REQUESTS");

        String comparisionResultsFile = WorkloadAnalyzerConfig.COMPARISION_RESULTS_FILE_NAME + WorkloadAnalyzerConfig.COMPARISION_RESULTS_FILE_EXTENTION;
        List<String> comparisionResultsLines = new ArrayList<String>();
        comparisionResultsLines.add("TEST-CONDITION,TEST-NAME,REQUESTS");
        List<TestResultObject> results = new ArrayList<TestResultObject>();

        testResultMap.forEach((testName, atemplatesMap) -> {
            atemplatesMap.forEach((noOfTemplates, aConnsPerTargetMap) -> {
//            LOG.info("Templates: "+noOfTemplates);
                aConnsPerTargetMap.forEach((noOfConnsPerTarget, aKeepAliveMap) -> {
//                LOG.info("Connections: "+noOfConnsPerTarget);
                    aKeepAliveMap.forEach((keepAlives, rps) -> {
//                    LOG.info("KeepAlives: "+keepAlives);
//                    LOG.info("rps: "+rps);
//                    lines.add(noOfTemplates+"     "+noOfConnsPerTarget+"      "+keepAlives+"       "+rps);
                        consolidatedResultsLines.add(testName+","+noOfTemplates+","+noOfConnsPerTarget+","+keepAlives+","+rps.trim());
                        results.add(new TestResultObject(noOfTemplates+"-"+noOfConnsPerTarget+"-"+keepAlives,testName,rps.trim()));
//                        comparisionResultsLines.add(noOfTemplates+"-"+noOfConnsPerTarget+"-"+keepAlives+","+testName+","+rps.trim());
                    });
                });
            });
        });
        Collections.sort(results);

        for (TestResultObject aResult: results) {
            comparisionResultsLines.add(aResult.toString());
        }
        try {
            FileUtils.writeLines(new File(consolidatedResultsFile), consolidatedResultsLines, true);
            FileUtils.writeLines(new File(comparisionResultsFile), comparisionResultsLines, true);
        } catch (IOException e) {
            e.printStackTrace();
            LOG.info("Error writing the files");
        }
        LOG.info("End of processing");
        }

    public void analyzereports(String commaSeperatedURLs) throws IOException {
        String [] urls = commaSeperatedURLs.split(",");
        LOG.info("The number of files given for processing:"+urls.length);
        for (int i = 0; i < urls.length ; i++) {
          downloadReport(urls[i]);
        }

        getReport();
    }

    public static void main(String[] args){
        // clean the input files

        try {
            LOG.info("Cleaning input files");
            File resultsDirectory = new File(WorkloadAnalyzerConfig.TEST_RESULTS_DIRECTORY);
            if (!resultsDirectory.isDirectory()) {
                FileUtils.forceMkdir(resultsDirectory);
            } else {
                FileUtils.cleanDirectory(resultsDirectory);
                LOG.info("deleted the results directory");
            }
            File inputDirectory = new File(WorkloadAnalyzerConfig.TEST_INPUT_FILES_DIRECTORY);
            if (!inputDirectory.isDirectory()) {
                FileUtils.forceMkdir(inputDirectory);
            } else {
                FileUtils.cleanDirectory(inputDirectory);
                LOG.info("deleted the input directory");
            }
        } catch (IOException e) {
            e.printStackTrace();
            LOG.debug("Error cleaning the directories");
        }

        WorkloadParser aParser = new WorkloadParser();
        if(args==null || args.length==0){
         System.out.println("Please enter urls of the workload data seperated by comma.");
        }else {
            try {
                aParser.analyzereports(args[0]);
            } catch (IOException e) {
                e.printStackTrace();
                LOG.info("Error in analyzing the reports");
            }
        }
    }

}
