package main

/* Imports */
import (
	"bufio"		// bufio.NewReader()
	"flag"		// command-line options parsing
	"fmt"		// fmt.Fprintf()
	"io"		// io.Reader()
	"os"		// os.Exit()
	"sort"		// sort.Sort()
	"strconv"	// strconv.ParseFloat()
)

/* Constants */
const (
	PNAME		= "pctl"
	DELIMITER	= "\t"
)

/* Global variables */
var numbers sort.Float64Slice
var show_pctls = []float64{}

/* Options */
var p_delimiter = DELIMITER		// default delimiter
var p_lenient = flag.Bool("l", false, "lenient mode, do not fail if percentile too low => return minumum value")

/* Functions */
func parse_cmd_opts() []string {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options] [list of percentiles to show]\n", PNAME)
		fmt.Fprintf(os.Stderr, "Example:  seq 1 1000 | ./%s -d '\\n' 68.27 95.45 99.73\n\n", PNAME)
		fmt.Fprintf(os.Stderr, "Options:\n")

		flag.PrintDefaults()
	}

	flag.StringVar(&p_delimiter, "d", p_delimiter, "delimiter, percentile separator")

	flag.Parse() // to execute the command-line parsing

	return flag.Args()
}

func UnquoteDelimiter(s string) string {
	var sep string
	s = `"` + s + `"`
	fmt.Sscanf(s, "%q", &sep)
	return sep
}

func percentile(r io.Reader, stdout io.Writer, stderr io.Writer) error {
	reader := bufio.NewReader(r)
	var line []byte
	var err error
	var f float64
	for {
		if line, _, err = reader.ReadLine(); err == io.EOF {
			break
		} else if err != nil {
			panic(err)
		}

		f, err = strconv.ParseFloat(string(line), 64)
		if err != nil {
			fmt.Fprintf(stderr, "`%s' is not a number: %s\n", string(line), err)
			os.Exit(1)
		}

		numbers = append(numbers, f)
	}
	if len(numbers) == 0 {
		fmt.Fprintf(os.Stderr, "no input data\n")
		os.Exit(1)
	}

	sort.Sort(numbers)
	l := len(numbers)

	if len(show_pctls) == 0 {
		for i := 1; i <= 100; i++ {
			printPercentileN(stdout, &numbers, l, float64(i), i != 1)
		}
	} else {
		for i := 0; i < len(show_pctls); i++ {
			printPercentileN(stdout, &numbers, l, show_pctls[i], i != 0)
		}
	}
	
	fmt.Fprintf(stdout, "\n")

	return nil
}

func percentileN(numbers *sort.Float64Slice, l int, n float64) float64 {
	i := int(n*float64(l)/100) - 1
	ns := *numbers

	if i < 0 && *p_lenient { i = 0 }
	if i < 0 {
		fmt.Fprintf(os.Stderr, "`%e' too low, no numbers fit the criteria, raise the percentile or use -l\n", n)
		os.Exit(1)
	}
	return ns[i]
}

func printPercentileN(w io.Writer, numbers *sort.Float64Slice, l int, n float64, sep bool) {
        if sep { fmt.Fprintf(w, "%s", UnquoteDelimiter(p_delimiter)) }
	fmt.Fprintf(w, "%s", strconv.FormatFloat(percentileN(numbers, l, n), 'g', 16, 64))
}

func main() {
	argv := parse_cmd_opts()

	for i := 0; i < len(argv); i++ {
		f, err := strconv.ParseFloat(argv[i], 64)
		if err != nil {
			fmt.Fprintf(os.Stderr, "`%s' is not a number: %s\n", argv[i], err)
			os.Exit(1)
		}
		if f <= 0 || f > 100 {
			fmt.Fprintf(os.Stderr, "`%s' not within (0,100>\n", argv[i])
			os.Exit(1)
		}
		show_pctls = append(show_pctls, f)
	}

	err := percentile(os.Stdin, os.Stdout, os.Stderr)
	if err != nil {
		panic(err)
	}
}
