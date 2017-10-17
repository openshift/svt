package main

import (
	"bufio"
	"encoding/csv"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/sjug/go-logparse/stats"
)

var searchDir, resultDir, processes string
var processList []string
var blockDevices, netDevices stringSlice
var fileHeader = map[string][]string{}

type stringSlice []string

type host struct {
	kind      string
	resultDir string
	results   []resultType
}

type resultType struct {
	kind, path           string
	min, max, avg, pct95 float64
}

func (s *stringSlice) String() string {
	return fmt.Sprintf("%v", *s)
}

func (s *stringSlice) Set(value string) error {
	*s = append(*s, value)
	return nil
}

func initFlags() {
	flag.StringVar(&searchDir, "i", "/var/lib/pbench-agent/benchmark_result/tools-default/", "pbench run result directory to parse")
	flag.StringVar(&resultDir, "o", "/tmp/", "output directory for parsed CSV result data")
	flag.StringVar(&processes, "proc", "openshift_start_master_api,openshift_start_master_controll,openshift_start_node,/etcd", "list of processes to gather")
	flag.Var(&blockDevices, "blkdev", "List of block devices")
	flag.Var(&netDevices, "netdev", "List of network devices")
	flag.Parse()
}

func main() {
	var hosts []host
	// This regexp matches the prefix to each pbench host result directory name
	// which indicates host type. (ie. svt-master-1:pbench-benchmark-001/)
	hostRegex := regexp.MustCompile(`svt[_-][elmn]\w*[_-]\d`)
	initFlags()

	// Check if no flags were passed, print help
	if flag.NFlag() == 0 {
		flag.PrintDefaults()
		return
	}

	// Ensure output directory has a trailing slash
	if string(resultDir[len(resultDir)-1]) != "/" {
		resultDir = resultDir + "/"
	}

	// If no block devices were passed, don't add to search
	if len(blockDevices) > 0 {
		fileHeader["disk_IOPS.csv"] = []string(blockDevices)
	}

	// If no network devices were passed, don't add to search
	if len(netDevices) > 0 {
		fileHeader["network_l2_network_packets_sec.csv"] = []string(netDevices)
		fileHeader["network_l2_network_Mbits_sec.csv"] = []string(netDevices)
	}

	processList = strings.Split(processes, ",")
	// If no process names were passed, don't add to search
	if len(processList) > 0 {
		fileHeader["cpu_usage_percent_cpu.csv"] = processList
		fileHeader["memory_usage_resident_set_size.csv"] = processList
	}

	// Return director listing of searchDir
	dirList, err := ioutil.ReadDir(searchDir)
	if err != nil {
		log.Fatal(err)
	}

	// Iterate over directory contents
	for _, item := range dirList {
		// Match subdirectory that follows our pattern
		if hostRegex.MatchString(item.Name()) && item.IsDir() {
			kind := strings.Split(item.Name(), ":")
			newHost := host{
				kind:      kind[0],
				resultDir: searchDir + item.Name(),
			}
			hosts = append(hosts, newHost)
		}
	}

	// Maps are not ordered, create ordered slice of keys and sort
	// This ensures that the file output is identical between execution
	keys := []string{}
	for k := range fileHeader {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	// Iterate over all known hosts
	for i, host := range hosts {
		fmt.Printf("Host: %+v\n", host)
		// Find each raw data CSV
		for _, key := range keys {
			fmt.Println(key)
			fileList := findFile(host.resultDir, key)
			// findFile returns slice, though there should only be one file
			for _, file := range fileList {
				// Parse file into 2d-string slice
				result, err := readCSV(file)
				if err != nil {
					fmt.Printf("Error reading %v: %v\n", file, err)
					continue
				}
				// In a single file we have multiple headers to extract
				for _, header := range fileHeader[key] {
					// Extract single column of data that we want
					newResult, err := newSlice(result, header)
					if err != nil {
						//need to keep list of columns same for all types
						//continue
						fmt.Printf("newSlice returned error: %v\n", err)
					}

					// Mutate host to add calcuated stats to object
					hosts[i].addResult(newResult, file, header)

				}
				fmt.Printf("CALLER Host populated: %+v\n", hosts[i])

			}
		}
	}

	err = writeCSV(keys, hosts)
	if err != nil {
		fmt.Printf("Error writing CSV: %v", err)
	}
}

func writeCSV(keys []string, hosts []host) error {
	csvFile, err := os.Create(resultDir + "out.csv")
	if err != nil {
		return err
	}
	defer csvFile.Close()

	// Write test CSV data to stdout
	writer := csv.NewWriter(csvFile)
	defer writer.Flush()

	// Create header & write
	header := createHeaders(keys)
	for _, h := range header {
		writer.Write(h)
	}

	// TODO: Maybe use reflection to get these fields instead
	stats := []string{"min", "mean", "p95", "max"}
	// Write all stats
	for _, v := range stats {
		writer.Write([]string{v})
		// Write result dataset
		for i := range hosts {
			writer.Write(hosts[i].toSlice(v))
		}
	}
	return nil
}

func createHeaders(keys []string) (header [][]string) {
	empty := []string{""}
	header = append(header, empty)
	header = append(header, empty)
	for _, key := range keys {
		// header keys are filenames, so we want to truncate the extension
		k := strings.Split(key, ".")
		for i := 0; i < len(fileHeader[key]); i++ {
			header[0] = append(header[0], k[0])
		}
		for _, head := range fileHeader[key] {
			header[1] = append(header[1], cleanWord(head))

		}
	}
	return
}

func cleanWord(dirty string) string {
	reg := regexp.MustCompile(`[^\w|-]+`)
	return reg.ReplaceAllString(dirty, "")
}

func readCSV(file string) ([][]string, error) {
	fmt.Println(file)
	f, err := os.Open(file)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	r := csv.NewReader(bufio.NewReader(f))
	result, err := r.ReadAll()
	if err != nil {
		return nil, err
	}

	return result, nil
}

func (h *host) toSlice(stat string) (row []string) {
	row = append(row, h.kind)
	switch stat {
	case "min":
		// append minimum
		for _, result := range h.results {
			row = append(row, strconv.FormatFloat(result.min, 'f', 2, 64))
		}
	case "mean":
		// appened mean
		for _, result := range h.results {
			row = append(row, strconv.FormatFloat(result.avg, 'f', 2, 64))
		}
	case "p95":
		// append p95
		for _, result := range h.results {
			row = append(row, strconv.FormatFloat(result.pct95, 'f', 2, 64))
		}
	case "max":
		// append max
		for _, result := range h.results {
			row = append(row, strconv.FormatFloat(result.max, 'f', 2, 64))
		}
	default:
		// do nothing
	}
	return
}

func (h *host) addResult(newResult []float64, file string, kind string) []resultType {
	min, _ := stats.Minimum(newResult)
	max, _ := stats.Maximum(newResult)
	avg, _ := stats.Mean(newResult)
	pct95, _ := stats.Percentile(newResult, 95)

	h.results = append(h.results, resultType{
		kind:  kind,
		path:  file,
		min:   min,
		max:   max,
		avg:   avg,
		pct95: pct95,
	})

	return h.results

}

func findFile(dir string, ext string) []string {
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		log.Fatal(err)
	}
	var fileList []string
	filepath.Walk(dir, func(path string, f os.FileInfo, err error) error {
		r, err := regexp.MatchString(ext, f.Name())
		if err == nil && r {
			fileList = append(fileList, path)
		}
		return nil
	})
	return fileList
}

func newSlice(bigSlice [][]string, title string) ([]float64, error) {
	floatValues := make([]float64, len(bigSlice)-1)
	var column int
	for i, v := range bigSlice {
		if i == 0 {
			var err error
			column, err = stringPositionInSlice(title, v)
			if err != nil {
				log.Println(err)
				return nil, err
			}
			continue
		}
		value, _ := strconv.ParseFloat(bigSlice[i][column], 64)
		floatValues[i-1] = value
	}
	return floatValues, nil
}

// TODO: handle duplicates or none
func stringPositionInSlice(a string, list []string) (int, error) {
	for i, v := range list {
		match, _ := regexp.MatchString(a, v)
		if match {
			return i, nil
		}
	}
	return 0, fmt.Errorf("No matching headers")
}
