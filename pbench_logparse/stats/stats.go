package stats

import (
	"fmt"
	"math"
	"sort"
)

func sum(input []float64) (sum float64) {
	for _, value := range input {
		sum += value
	}
	return
}

// Mean calculates the arithmetic mean of a slice of float64 numbers
func Mean(input []float64) (float64, error) {
	if len(input) == 0 {
		return math.NaN(), fmt.Errorf("Invalid float slice: %g", input)
	}

	return sum(input) / float64(len(input)), nil
}

// Minimum returns the lowest number in a slice of float64 numbers
func Minimum(input []float64) (min float64, err error) {
	if len(input) == 0 {
		return math.NaN(), fmt.Errorf("Invalid float slice: %g", input)
	}

	min = input[0]
	for _, value := range input {
		if value < min {
			min = value
		}
	}
	return min, nil
}

// Maximum returns the highest number in a slice of float64 numbers
func Maximum(input []float64) (max float64, err error) {
	if len(input) == 0 {
		return math.NaN(), fmt.Errorf("Invalid float slice: %g", input)
	}

	max = input[0]
	for _, value := range input {
		if value > max {
			max = value
		}
	}
	return max, nil
}

// Percentile returns the k-th percentile of values in a range of numbers
func Percentile(input []float64, percent float64) (percentile float64, err error) {
	if len(input) == 0 {
		return math.NaN(), fmt.Errorf("Invalid float slice: %g", input)
	}

	sort.Float64s(input)
	index := (percent / 100) * float64(len(input)-1)
	// If index happens to be a round number
	if index == float64(int64(index)) {
		i := int(index)
		return input[i], nil
	}

	// Otherwise interpolate percentile value
	k := math.Floor(index)
	f := index - k
	if int(k) >= len(input) {
		return math.NaN(), fmt.Errorf("Invalid index: %v/%v", k+1, len(input))
	}
	percentile = ((1 - f) * input[int(k)]) + (f * input[int(k)+1])
	return percentile, nil
}
