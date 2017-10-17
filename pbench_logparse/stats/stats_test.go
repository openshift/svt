package stats

import "testing"

type teststruct struct {
	values []float64
	sum    float64
	mean   float64
	min    float64
	max    float64
	p95    float64
}

var tests = []teststruct{
	// Floating precision error result kept intact for percentile result, rounding done in print, not in Percentile function
	{[]float64{1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37, 39, 41, 43, 45, 47, 49}, 625, 25, 1, 49, 46.599999999999994},
}

func TestSum(t *testing.T) {
	for _, v := range tests {
		sum := sum(v.values)
		if sum != v.sum {
			t.Errorf("For %v, expected %v instead we got %v", v.values, v.sum, sum)
		}
	}
}

func TestMean(t *testing.T) {
	for _, v := range tests {
		avg, _ := Mean(v.values)
		if avg != v.mean {
			t.Errorf("For %v, expected %v instead we got %v", v.values, v.mean, avg)
		}
	}
}

func TestMinimum(t *testing.T) {
	for _, v := range tests {
		min, _ := Minimum(v.values)
		if min != v.min {
			t.Errorf("For %v, expected %v instead we got %v", v.values, v.min, min)
		}
	}
}

func TestMaximum(t *testing.T) {
	for _, v := range tests {
		max, _ := Maximum(v.values)
		if max != v.max {
			t.Errorf("For %v, expected %v instead we got %v", v.values, v.max, max)
		}
	}
}

func TestPercentile95(t *testing.T) {
	for _, v := range tests {
		p95, _ := Percentile(v.values, 95)
		if p95 != v.p95 {
			t.Errorf("For %v, expected %v instead we got %v", v.values, v.p95, p95)
		}
	}
}
