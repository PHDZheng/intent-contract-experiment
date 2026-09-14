#!/usr/bin/env bash
set -e

cd /app

# Step 1: Modify main.go to add new switch cases and struct fields
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

# Patch 1: Add new fields to TransformOp struct (after Strategy line)
code = code.replace(
    '\tStrategy     string        `json:"strategy,omitempty"`\n}',
    '\tStrategy     string        `json:"strategy,omitempty"`\n\tDelimiter    string        `json:"delimiter,omitempty"`\n\tNames        []string      `json:"names,omitempty"`\n\tMessage      string        `json:"message,omitempty"`\n\tKeep         string        `json:"keep,omitempty"`\n\tMethod       string        `json:"method,omitempty"`\n\tDrop         bool          `json:"drop,omitempty"`\n\tFactor       float64       `json:"factor,omitempty"`\n\tBins         int           `json:"bins,omitempty"`\n}'
)

# Patch 2: Add "profile" and "compare" cases to main() switch (before "pipeline")
code = code.replace(
    '\tcase "pipeline":\n\t\terr = runPipeline(args)',
    '\tcase "profile":\n\t\terr = runProfile(args)\n\tcase "compare":\n\t\terr = runCompare(args)\n\tcase "pipeline":\n\t\terr = runPipeline(args)'
)

# Patch 3: Add new transform cases to runTransform switch (before "fill")
code = code.replace(
    '\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)',
    '\t\tcase "deduplicate":\n\t\t\theader, rows, opErr = applyDeduplicate(header, rows, op)\n\t\tcase "split":\n\t\t\theader, rows, opErr = applySplit(header, rows, op)\n\t\tcase "assert":\n\t\t\theader, rows, opErr = applyAssert(header, rows, op)\n\t\tcase "normalize":\n\t\t\theader, rows, opErr = applyNormalize(header, rows, op)\n\t\tcase "hash":\n\t\t\theader, rows, opErr = applyHash(header, rows, op)\n\t\tcase "encode":\n\t\t\theader, rows, opErr = applyEncode(header, rows, op)\n\t\tcase "rollup":\n\t\t\theader, rows, opErr = applyRollup(header, rows, op)\n\t\tcase "detect":\n\t\t\theader, rows, opErr = applyDetect(header, rows, op)\n\t\tcase "bin":\n\t\t\theader, rows, opErr = applyBin(header, rows, op)\n\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)'
)

# Patch 4: Add "profile" and "compare" to pipeline switch (before "manifest")
code = code.replace(
    '\t\tcase "manifest":\n\t\t\tstepErr = runManifest([]string{"--dir", step.Dir, "--output", step.Output})',
    '\t\tcase "profile":\n\t\t\tstepErr = runProfile([]string{"--input", step.Input, "--output", step.Output})\n\t\tcase "compare":\n\t\t\tstepErr = runCompare([]string{"--left", step.Left, "--right", step.Right, "--key", step.Key, "--output", step.Output})\n\t\tcase "manifest":\n\t\t\tstepErr = runManifest([]string{"--dir", step.Dir, "--output", step.Output})'
)

# Patch 5: Add "linear" case to applyFill switch (after "constant", before closing brace)
code = code.replace(
    '\tcase "constant":\n\t\tfor _, ci := range colIndices {\n\t\t\tfor i := 0; i < len(newRows); i++ {\n\t\t\t\tif ci < len(newRows[i]) && newRows[i][ci] == "" {\n\t\t\t\t\tnewRows[i][ci] = op.Value\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}',
    '\tcase "constant":\n\t\tfor _, ci := range colIndices {\n\t\t\tfor i := 0; i < len(newRows); i++ {\n\t\t\t\tif ci < len(newRows[i]) && newRows[i][ci] == "" {\n\t\t\t\t\tnewRows[i][ci] = op.Value\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\tcase "linear":\n\t\tfor _, ci := range colIndices {\n\t\t\tapplyFillLinear(newRows, ci)\n\t\t}\n\t}'
)

# Patch 6: Add Left, Right, Key fields to PipelineStep struct
code = code.replace(
    '\tDir      string `json:"dir,omitempty"`\n}',
    '\tDir      string `json:"dir,omitempty"`\n\tLeft     string `json:"left,omitempty"`\n\tRight    string `json:"right,omitempty"`\n\tKey      string `json:"key,omitempty"`\n}'
)

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 2: Create profile.go (with extended stats: skewness, kurtosis, mode, histogram, avg_length, correlations)
cat > profile.go << 'GOEOF'
package main

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"sort"
	"strconv"
	"time"
)

func runProfile(args []string) error {
	p := parseArgs(args)
	inputPath := p["input"]
	outputPath := p["output"]

	if _, err := os.Stat(inputPath); os.IsNotExist(err) {
		return fmt.Errorf("ERROR: file not found: %s", inputPath)
	}

	f, err := os.Open(inputPath)
	if err != nil {
		return fmt.Errorf("ERROR: file not found: %s", inputPath)
	}
	defer f.Close()

	reader := csv.NewReader(f)
	records, err := reader.ReadAll()
	if err != nil {
		return fmt.Errorf("ERROR: cannot parse CSV: %s", inputPath)
	}

	if len(records) == 0 {
		return fmt.Errorf("ERROR: empty CSV")
	}

	header := records[0]
	rows := records[1:]
	rowCount := len(rows)

	var columns []map[string]interface{}

	for colPos, colName := range header {
		var values []string
		nullCount := 0
		for _, row := range rows {
			if colPos < len(row) && row[colPos] != "" {
				values = append(values, row[colPos])
			} else {
				nullCount++
			}
		}

		count := len(values)
		uniqueSet := make(map[string]bool)
		for _, v := range values {
			uniqueSet[v] = true
		}
		unique := len(uniqueSet)

		colType := "string"
		var intVals []int64
		var floatVals []float64

		if count > 0 {
			allInt := true
			for _, v := range values {
				iv, err := strconv.ParseInt(v, 10, 64)
				if err != nil {
					allInt = false
					break
				}
				intVals = append(intVals, iv)
			}
			if allInt {
				colType = "int"
				for _, iv := range intVals {
					floatVals = append(floatVals, float64(iv))
				}
			} else {
				allFloat := true
				floatVals = nil
				for _, v := range values {
					fv, err := strconv.ParseFloat(v, 64)
					if err != nil {
						allFloat = false
						break
					}
					floatVals = append(floatVals, fv)
				}
				if allFloat {
					colType = "float"
				} else {
					allDT := true
					for _, v := range values {
						_, err := time.Parse(time.RFC3339, v)
						if err != nil {
							allDT = false
							break
						}
					}
					if allDT {
						colType = "datetime"
					}
				}
			}
		}

		profile := map[string]interface{}{
			"name":       colName,
			"type":       colType,
			"count":      count,
			"null_count": nullCount,
			"unique":     unique,
		}

		switch colType {
		case "int", "float":
			sort.Float64s(floatVals)
			if colType == "int" {
				profile["min"] = int64(floatVals[0])
				profile["max"] = int64(floatVals[len(floatVals)-1])
			} else {
				profile["min"] = floatVals[0]
				profile["max"] = floatVals[len(floatVals)-1]
			}

			sum := 0.0
			for _, v := range floatVals {
				sum += v
			}
			n := float64(count)
			mean := sum / n
			profile["mean"] = mean

			sumSqDiff := 0.0
			for _, v := range floatVals {
				d := v - mean
				sumSqDiff += d * d
			}
			popStddev := math.Sqrt(sumSqDiff / n)
			profile["stddev"] = popStddev
			profile["median"] = calcPercentile(floatVals, 50)
			profile["p25"] = calcPercentile(floatVals, 25)
			profile["p75"] = calcPercentile(floatVals, 75)

			if count >= 3 {
				sampleS := math.Sqrt(sumSqDiff / (n - 1))
				if sampleS > 0 {
					sumCubed := 0.0
					for _, v := range floatVals {
						z := (v - mean) / sampleS
						sumCubed += z * z * z
					}
					profile["skewness"] = (n / ((n - 1) * (n - 2))) * sumCubed
				} else {
					profile["skewness"] = nil
				}
			} else {
				profile["skewness"] = nil
			}

			if count >= 4 {
				sampleS := math.Sqrt(sumSqDiff / (n - 1))
				if sampleS > 0 {
					sumFourth := 0.0
					for _, v := range floatVals {
						z := (v - mean) / sampleS
						sumFourth += z * z * z * z
					}
					kurt := ((n*(n+1))/((n-1)*(n-2)*(n-3)))*sumFourth - (3*(n-1)*(n-1))/((n-2)*(n-3))
					profile["kurtosis"] = kurt
				} else {
					profile["kurtosis"] = nil
				}
			} else {
				profile["kurtosis"] = nil
			}

			freqMapF := make(map[float64]int)
			for _, v := range floatVals {
				freqMapF[v]++
			}
			maxFreq := 0
			for _, cnt := range freqMapF {
				if cnt > maxFreq {
					maxFreq = cnt
				}
			}
			allUnique := maxFreq <= 1
			if count > 0 && !allUnique {
				var candidates []float64
				for v, cnt := range freqMapF {
					if cnt == maxFreq {
						candidates = append(candidates, v)
					}
				}
				sort.Float64s(candidates)
				if colType == "int" {
					profile["mode"] = int64(candidates[0])
				} else {
					profile["mode"] = candidates[0]
				}
			} else {
				profile["mode"] = nil
			}

			if count > 0 {
				minF := floatVals[0]
				maxF := floatVals[len(floatVals)-1]
				if minF == maxF {
					singleBin := map[string]interface{}{"count": count}
					if colType == "int" {
						singleBin["low"] = int64(minF)
						singleBin["high"] = int64(maxF)
					} else {
						singleBin["low"] = minF
						singleBin["high"] = maxF
					}
					profile["histogram"] = []map[string]interface{}{singleBin}
				} else {
					width := (maxF - minF) / 10.0
					histBins := make([]map[string]interface{}, 10)
					for i := 0; i < 10; i++ {
						low := minF + float64(i)*width
						high := minF + float64(i+1)*width
						if i == 9 {
							high = maxF
						}
						histBins[i] = map[string]interface{}{
							"low":   low,
							"high":  high,
							"count": 0,
						}
					}
					for _, v := range floatVals {
						idx := int(math.Floor((v - minF) / width))
						if idx >= 10 {
							idx = 9
						}
						if idx < 0 {
							idx = 0
						}
						histBins[idx]["count"] = histBins[idx]["count"].(int) + 1
					}
					profile["histogram"] = histBins
				}
			} else {
				profile["histogram"] = make([]map[string]interface{}, 0)
			}

		case "string":
			if count > 0 {
				minLen := len(values[0])
				maxLen := len(values[0])
				totalLen := 0
				freqMap := make(map[string]int)
				for _, v := range values {
					l := len(v)
					if l < minLen {
						minLen = l
					}
					if l > maxLen {
						maxLen = l
					}
					totalLen += l
					freqMap[v]++
				}
				profile["min_length"] = minLen
				profile["max_length"] = maxLen
				profile["avg_length"] = float64(totalLen) / float64(count)

				type freqEntry struct {
					value string
					count int
				}
				var entries []freqEntry
				for v, c := range freqMap {
					entries = append(entries, freqEntry{v, c})
				}
				sort.Slice(entries, func(i, j int) bool {
					if entries[i].count != entries[j].count {
						return entries[i].count > entries[j].count
					}
					return entries[i].value < entries[j].value
				})

				top := 5
				if len(entries) < top {
					top = len(entries)
				}
				mc := make([]map[string]interface{}, top)
				for i := 0; i < top; i++ {
					mc[i] = map[string]interface{}{
						"value": entries[i].value,
						"count": entries[i].count,
					}
				}
				profile["most_common"] = mc
			} else {
				profile["min_length"] = 0
				profile["max_length"] = 0
				profile["avg_length"] = 0
				profile["most_common"] = make([]map[string]interface{}, 0)
			}

		case "datetime":
			var times []time.Time
			for _, v := range values {
				t, _ := time.Parse(time.RFC3339, v)
				times = append(times, t)
			}
			sort.Slice(times, func(i, j int) bool {
				return times[i].Before(times[j])
			})
			profile["earliest"] = times[0].Format(time.RFC3339)
			profile["latest"] = times[len(times)-1].Format(time.RFC3339)
		}

		columns = append(columns, profile)
	}

	type numCol struct {
		name string
		pos  int
	}
	var numericCols []numCol
	for i, col := range columns {
		ct := col["type"].(string)
		if ct == "int" || ct == "float" {
			numericCols = append(numericCols, numCol{col["name"].(string), i})
		}
	}

	var correlations []map[string]interface{}
	for i := 0; i < len(numericCols); i++ {
		for j := i + 1; j < len(numericCols); j++ {
			posA := numericCols[i].pos
			posB := numericCols[j].pos

			var valsA, valsB []float64
			for _, row := range rows {
				aStr, bStr := "", ""
				if posA < len(row) {
					aStr = row[posA]
				}
				if posB < len(row) {
					bStr = row[posB]
				}
				if aStr != "" && bStr != "" {
					va, errA := strconv.ParseFloat(aStr, 64)
					vb, errB := strconv.ParseFloat(bStr, 64)
					if errA == nil && errB == nil {
						valsA = append(valsA, va)
						valsB = append(valsB, vb)
					}
				}
			}

			nPaired := len(valsA)
			entry := map[string]interface{}{
				"column_a": numericCols[i].name,
				"column_b": numericCols[j].name,
			}

			if nPaired < 2 {
				entry["correlation"] = nil
			} else {
				sumA, sumB := 0.0, 0.0
				for k := 0; k < nPaired; k++ {
					sumA += valsA[k]
					sumB += valsB[k]
				}
				meanA := sumA / float64(nPaired)
				meanB := sumB / float64(nPaired)

				num := 0.0
				denomA := 0.0
				denomB := 0.0
				for k := 0; k < nPaired; k++ {
					da := valsA[k] - meanA
					db := valsB[k] - meanB
					num += da * db
					denomA += da * da
					denomB += db * db
				}

				denom := math.Sqrt(denomA * denomB)
				if denom == 0 {
					entry["correlation"] = nil
				} else {
					entry["correlation"] = num / denom
				}
			}

			correlations = append(correlations, entry)
		}
	}

	if correlations == nil {
		correlations = make([]map[string]interface{}, 0)
	}

	output := map[string]interface{}{
		"row_count":    rowCount,
		"columns":      columns,
		"correlations": correlations,
	}

	data, _ := json.MarshalIndent(output, "", "  ")
	return os.WriteFile(outputPath, append(data, '\n'), 0644)
}

func calcPercentile(sorted []float64, p float64) float64 {
	n := len(sorted)
	if n == 0 {
		return 0
	}
	if n == 1 {
		return sorted[0]
	}
	idx := p / 100.0 * float64(n-1)
	lower := int(math.Floor(idx))
	upper := int(math.Ceil(idx))
	if lower == upper {
		return sorted[lower]
	}
	frac := idx - float64(lower)
	return sorted[lower] + frac*(sorted[upper]-sorted[lower])
}
GOEOF

# Step 3: Create transforms2.go (deduplicate, split, assert, normalize, fill linear, hash)
cat > transforms2.go << 'GOEOF'
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math"
	"strconv"
	"strings"
)

func applyDeduplicate(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	cols := op.Columns
	if len(cols) == 0 {
		cols = make([]string, len(header))
		copy(cols, header)
	}

	var colIndices []int
	for _, c := range cols {
		idx := colIndex(header, c)
		if idx < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", c)
		}
		colIndices = append(colIndices, idx)
	}

	makeKey := func(row []string) string {
		parts := make([]string, len(colIndices))
		for i, idx := range colIndices {
			if idx < len(row) {
				parts[i] = row[idx]
			}
		}
		return strings.Join(parts, "\x00")
	}

	if op.Keep == "first" {
		seen := make(map[string]bool)
		var result [][]string
		for _, row := range rows {
			key := makeKey(row)
			if !seen[key] {
				seen[key] = true
				result = append(result, row)
			}
		}
		return header, result, nil
	}

	lastIdx := make(map[string]int)
	for i, row := range rows {
		key := makeKey(row)
		lastIdx[key] = i
	}

	keepSet := make(map[int]bool)
	for _, idx := range lastIdx {
		keepSet[idx] = true
	}

	var result [][]string
	for i, row := range rows {
		if keepSet[i] {
			result = append(result, row)
		}
	}
	return header, result, nil
}

func applySplit(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	srcIdx := colIndex(header, op.Column)
	if srcIdx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}

	numNames := len(op.Names)

	newHeader := make([]string, 0, len(header)-1+numNames)
	newHeader = append(newHeader, header[:srcIdx]...)
	newHeader = append(newHeader, op.Names...)
	newHeader = append(newHeader, header[srcIdx+1:]...)

	var result [][]string
	for _, row := range rows {
		val := ""
		if srcIdx < len(row) {
			val = row[srcIdx]
		}

		parts := strings.Split(val, op.Delimiter)

		adjusted := make([]string, numNames)
		for i := 0; i < numNames; i++ {
			if i < numNames-1 {
				if i < len(parts) {
					adjusted[i] = parts[i]
				}
			} else {
				if i < len(parts) {
					adjusted[i] = strings.Join(parts[i:], op.Delimiter)
				}
			}
		}

		newRow := make([]string, 0, len(row)-1+numNames)
		newRow = append(newRow, row[:srcIdx]...)
		newRow = append(newRow, adjusted...)
		if srcIdx+1 < len(row) {
			newRow = append(newRow, row[srcIdx+1:]...)
		}
		result = append(result, newRow)
	}

	return newHeader, result, nil
}

func applyAssert(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	for i, row := range rows {
		val := evalExpr(op.Expression, header, row)
		if val <= 0 || math.IsNaN(val) {
			return nil, nil, fmt.Errorf("ERROR: assertion failed on row %d: %s", i+1, op.Message)
		}
	}
	return header, rows, nil
}

func applyNormalize(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	srcIdx := colIndex(header, op.Column)
	if srcIdx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}

	var numericVals []float64
	for _, row := range rows {
		if srcIdx < len(row) && row[srcIdx] != "" {
			v, err := strconv.ParseFloat(row[srcIdx], 64)
			if err == nil {
				numericVals = append(numericVals, v)
			}
		}
	}

	var mean, stddev, minV, maxV float64
	n := len(numericVals)
	if n > 0 {
		sum := 0.0
		minV = numericVals[0]
		maxV = numericVals[0]
		for _, v := range numericVals {
			sum += v
			if v < minV {
				minV = v
			}
			if v > maxV {
				maxV = v
			}
		}
		mean = sum / float64(n)
		sumSqDiff := 0.0
		for _, v := range numericVals {
			d := v - mean
			sumSqDiff += d * d
		}
		stddev = math.Sqrt(sumSqDiff / float64(n))
	}

	newHeader := make([]string, len(header)+1)
	copy(newHeader, header)
	newHeader[len(header)] = op.As

	var result [][]string
	for _, row := range rows {
		newRow := make([]string, len(header)+1)
		copy(newRow, row)

		val := ""
		if srcIdx < len(row) && row[srcIdx] != "" {
			v, err := strconv.ParseFloat(row[srcIdx], 64)
			if err == nil {
				switch op.Method {
				case "zscore":
					if stddev == 0 {
						val = "0"
					} else {
						val = formatFloat((v - mean) / stddev)
					}
				case "minmax":
					if maxV == minV {
						val = "0"
					} else {
						val = formatFloat((v - minV) / (maxV - minV))
					}
				}
			}
		}
		newRow[len(header)] = val
		result = append(result, newRow)
	}
	return newHeader, result, nil
}

func applyFillLinear(rows [][]string, ci int) {
	for i := 0; i < len(rows); i++ {
		if ci < len(rows[i]) && rows[i][ci] == "" {
			lowerIdx := -1
			lowerVal := 0.0
			for j := i - 1; j >= 0; j-- {
				if ci < len(rows[j]) && rows[j][ci] != "" {
					v, err := strconv.ParseFloat(rows[j][ci], 64)
					if err == nil {
						lowerIdx = j
						lowerVal = v
						break
					}
				}
			}
			upperIdx := -1
			upperVal := 0.0
			for j := i + 1; j < len(rows); j++ {
				if ci < len(rows[j]) && rows[j][ci] != "" {
					v, err := strconv.ParseFloat(rows[j][ci], 64)
					if err == nil {
						upperIdx = j
						upperVal = v
						break
					}
				}
			}
			if lowerIdx >= 0 && upperIdx >= 0 {
				frac := float64(i-lowerIdx) / float64(upperIdx-lowerIdx)
				result := lowerVal + (upperVal-lowerVal)*frac
				rows[i][ci] = formatFloat(result)
			}
		}
	}
}

func applyHash(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	cols := op.Columns
	if len(cols) == 0 {
		cols = make([]string, len(header))
		copy(cols, header)
	}

	var colIndices []int
	for _, c := range cols {
		idx := colIndex(header, c)
		if idx < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", c)
		}
		colIndices = append(colIndices, idx)
	}

	newHeader := make([]string, len(header)+1)
	copy(newHeader, header)
	newHeader[len(header)] = op.As

	var newRows [][]string
	for _, row := range rows {
		var parts []string
		for _, ci := range colIndices {
			if ci < len(row) {
				parts = append(parts, row[ci])
			} else {
				parts = append(parts, "")
			}
		}
		input := strings.Join(parts, "\x00")
		h := sha256.Sum256([]byte(input))
		hashStr := hex.EncodeToString(h[:])

		newRow := make([]string, len(row)+1)
		copy(newRow, row)
		newRow[len(row)] = hashStr
		newRows = append(newRows, newRow)
	}

	return newHeader, newRows, nil
}
GOEOF

# Step 4: Create transforms3.go (encode, rollup, detect, bin)
cat > transforms3.go << 'GOEOF'
package main

import (
	"fmt"
	"math"
	"sort"
	"strconv"
	"strings"
)

func applyEncode(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	srcIdx := colIndex(header, op.Column)
	if srcIdx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}

	switch op.Method {
	case "onehot":
		uniqueSet := make(map[string]bool)
		for _, row := range rows {
			if srcIdx < len(row) && row[srcIdx] != "" {
				uniqueSet[row[srcIdx]] = true
			}
		}
		var uniqueVals []string
		for v := range uniqueSet {
			uniqueVals = append(uniqueVals, v)
		}
		sort.Strings(uniqueVals)

		newColNames := make([]string, len(uniqueVals))
		for i, v := range uniqueVals {
			newColNames[i] = op.Column + "_" + v
		}

		var newHeader []string
		if op.Drop {
			newHeader = make([]string, 0, len(header)-1+len(newColNames))
			newHeader = append(newHeader, header[:srcIdx]...)
			newHeader = append(newHeader, newColNames...)
			if srcIdx+1 < len(header) {
				newHeader = append(newHeader, header[srcIdx+1:]...)
			}
		} else {
			newHeader = make([]string, 0, len(header)+len(newColNames))
			newHeader = append(newHeader, header...)
			newHeader = append(newHeader, newColNames...)
		}

		var newRows [][]string
		for _, row := range rows {
			val := ""
			if srcIdx < len(row) {
				val = row[srcIdx]
			}

			hotVals := make([]string, len(uniqueVals))
			for i, uv := range uniqueVals {
				if val == uv {
					hotVals[i] = "1"
				} else {
					hotVals[i] = "0"
				}
			}

			var newRow []string
			if op.Drop {
				newRow = make([]string, 0, len(row)-1+len(hotVals))
				if srcIdx > 0 {
					newRow = append(newRow, row[:srcIdx]...)
				}
				newRow = append(newRow, hotVals...)
				if srcIdx+1 < len(row) {
					newRow = append(newRow, row[srcIdx+1:]...)
				}
			} else {
				newRow = make([]string, 0, len(row)+len(hotVals))
				newRow = append(newRow, row...)
				newRow = append(newRow, hotVals...)
			}
			newRows = append(newRows, newRow)
		}

		return newHeader, newRows, nil

	case "ordinal":
		uniqueSet := make(map[string]bool)
		for _, row := range rows {
			if srcIdx < len(row) && row[srcIdx] != "" {
				uniqueSet[row[srcIdx]] = true
			}
		}
		var uniqueVals []string
		for v := range uniqueSet {
			uniqueVals = append(uniqueVals, v)
		}
		sort.Strings(uniqueVals)

		rankMap := make(map[string]int)
		for i, v := range uniqueVals {
			rankMap[v] = i
		}

		newHeader := make([]string, len(header)+1)
		copy(newHeader, header)
		newHeader[len(header)] = op.As

		var newRows [][]string
		for _, row := range rows {
			newRow := make([]string, len(header)+1)
			copy(newRow, row)
			val := ""
			if srcIdx < len(row) {
				val = row[srcIdx]
			}
			if val == "" {
				newRow[len(header)] = ""
			} else if rank, ok := rankMap[val]; ok {
				newRow[len(header)] = strconv.Itoa(rank)
			}
			newRows = append(newRows, newRow)
		}

		return newHeader, newRows, nil
	}

	return header, rows, nil
}

func applyRollup(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	var colIndices []int
	for _, c := range op.Columns {
		idx := colIndex(header, c)
		if idx < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", c)
		}
		colIndices = append(colIndices, idx)
	}

	var aggColIndices []int
	for _, agg := range op.Aggregations {
		idx := colIndex(header, agg.Column)
		if idx < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", agg.Column)
		}
		aggColIndices = append(aggColIndices, idx)
	}

	newHeader := make([]string, len(op.Columns))
	copy(newHeader, op.Columns)
	for _, agg := range op.Aggregations {
		newHeader = append(newHeader, agg.As)
	}

	computeAggs := func(rowSet [][]string) []string {
		var aggVals []string
		for k, agg := range op.Aggregations {
			srcIdx := aggColIndices[k]
			var numVals []float64
			nonEmpty := 0
			for _, row := range rowSet {
				if srcIdx < len(row) && row[srcIdx] != "" {
					nonEmpty++
					v, err := strconv.ParseFloat(row[srcIdx], 64)
					if err == nil {
						numVals = append(numVals, v)
					}
				}
			}

			var result string
			switch agg.Function {
			case "sum":
				s := 0.0
				for _, v := range numVals {
					s += v
				}
				result = formatFloat(s)
			case "avg":
				if len(numVals) == 0 {
					result = "NaN"
				} else {
					s := 0.0
					for _, v := range numVals {
						s += v
					}
					result = formatFloat(s / float64(len(numVals)))
				}
			case "count":
				result = strconv.Itoa(nonEmpty)
			case "min":
				if len(numVals) == 0 {
					result = "NaN"
				} else {
					m := numVals[0]
					for _, v := range numVals[1:] {
						if v < m {
							m = v
						}
					}
					result = formatFloat(m)
				}
			case "max":
				if len(numVals) == 0 {
					result = "NaN"
				} else {
					m := numVals[0]
					for _, v := range numVals[1:] {
						if v > m {
							m = v
						}
					}
					result = formatFloat(m)
				}
			}
			aggVals = append(aggVals, result)
		}
		return aggVals
	}

	numGroupCols := len(op.Columns)
	var allOutputRows [][]string

	detailGroups := make(map[string][][]string)
	var detailKeys []string
	for _, row := range rows {
		var keyParts []string
		for _, ci := range colIndices {
			if ci < len(row) {
				keyParts = append(keyParts, row[ci])
			} else {
				keyParts = append(keyParts, "")
			}
		}
		key := strings.Join(keyParts, "\x00")
		if _, exists := detailGroups[key]; !exists {
			detailKeys = append(detailKeys, key)
		}
		detailGroups[key] = append(detailGroups[key], row)
	}
	sort.Strings(detailKeys)

	for _, key := range detailKeys {
		parts := strings.Split(key, "\x00")
		aggVals := computeAggs(detailGroups[key])
		outputRow := make([]string, numGroupCols+len(op.Aggregations))
		copy(outputRow, parts)
		for i, av := range aggVals {
			outputRow[numGroupCols+i] = av
		}
		allOutputRows = append(allOutputRows, outputRow)
	}

	for level := numGroupCols - 1; level >= 1; level-- {
		subGroups := make(map[string][][]string)
		var subKeys []string
		for _, row := range rows {
			var keyParts []string
			for k := 0; k < level; k++ {
				ci := colIndices[k]
				if ci < len(row) {
					keyParts = append(keyParts, row[ci])
				} else {
					keyParts = append(keyParts, "")
				}
			}
			key := strings.Join(keyParts, "\x00")
			if _, exists := subGroups[key]; !exists {
				subKeys = append(subKeys, key)
			}
			subGroups[key] = append(subGroups[key], row)
		}
		sort.Strings(subKeys)

		for _, key := range subKeys {
			parts := strings.Split(key, "\x00")
			aggVals := computeAggs(subGroups[key])
			outputRow := make([]string, numGroupCols+len(op.Aggregations))
			for k := 0; k < level; k++ {
				outputRow[k] = parts[k]
			}
			for k := level; k < numGroupCols; k++ {
				outputRow[k] = "*"
			}
			for i, av := range aggVals {
				outputRow[numGroupCols+i] = av
			}
			allOutputRows = append(allOutputRows, outputRow)
		}
	}

	aggVals := computeAggs(rows)
	grandRow := make([]string, numGroupCols+len(op.Aggregations))
	for k := 0; k < numGroupCols; k++ {
		grandRow[k] = "*"
	}
	for i, av := range aggVals {
		grandRow[numGroupCols+i] = av
	}
	allOutputRows = append(allOutputRows, grandRow)

	return newHeader, allOutputRows, nil
}

func applyDetect(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	srcIdx := colIndex(header, op.Column)
	if srcIdx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}

	var numVals []float64
	for _, row := range rows {
		if srcIdx < len(row) && row[srcIdx] != "" {
			v, err := strconv.ParseFloat(row[srcIdx], 64)
			if err == nil {
				numVals = append(numVals, v)
			}
		}
	}

	factor := op.Factor
	var isOutlier func(float64) bool

	switch op.Method {
	case "iqr":
		if len(numVals) < 2 {
			isOutlier = func(v float64) bool { return false }
		} else {
			sorted := make([]float64, len(numVals))
			copy(sorted, numVals)
			sort.Float64s(sorted)
			q1 := calcPercentile(sorted, 25)
			q3 := calcPercentile(sorted, 75)
			iqr := q3 - q1
			lo := q1 - factor*iqr
			hi := q3 + factor*iqr
			isOutlier = func(v float64) bool {
				return v < lo || v > hi
			}
		}

	case "zscore":
		if len(numVals) == 0 {
			isOutlier = func(v float64) bool { return false }
		} else {
			nf := float64(len(numVals))
			sum := 0.0
			for _, v := range numVals {
				sum += v
			}
			mean := sum / nf
			sumSqDiff := 0.0
			for _, v := range numVals {
				d := v - mean
				sumSqDiff += d * d
			}
			stddev := math.Sqrt(sumSqDiff / nf)
			if stddev == 0 {
				isOutlier = func(v float64) bool { return false }
			} else {
				isOutlier = func(v float64) bool {
					return math.Abs(v-mean)/stddev > factor
				}
			}
		}

	case "mad":
		if len(numVals) == 0 {
			isOutlier = func(v float64) bool { return false }
		} else {
			sorted := make([]float64, len(numVals))
			copy(sorted, numVals)
			sort.Float64s(sorted)
			median := calcPercentile(sorted, 50)

			absDevs := make([]float64, len(numVals))
			for i, v := range numVals {
				absDevs[i] = math.Abs(v - median)
			}
			sort.Float64s(absDevs)
			mad := calcPercentile(absDevs, 50)

			if mad == 0 {
				isOutlier = func(v float64) bool {
					return v != median
				}
			} else {
				isOutlier = func(v float64) bool {
					modZ := 0.6745 * (v - median) / mad
					return math.Abs(modZ) > factor
				}
			}
		}
	}

	newHeader := make([]string, len(header)+1)
	copy(newHeader, header)
	newHeader[len(header)] = op.As

	var newRows [][]string
	for _, row := range rows {
		newRow := make([]string, len(header)+1)
		copy(newRow, row)

		val := ""
		if srcIdx < len(row) {
			val = row[srcIdx]
		}

		result := "0"
		if val != "" {
			v, err := strconv.ParseFloat(val, 64)
			if err == nil && isOutlier != nil && isOutlier(v) {
				result = "1"
			}
		}
		newRow[len(header)] = result
		newRows = append(newRows, newRow)
	}

	return newHeader, newRows, nil
}

func applyBin(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	srcIdx := colIndex(header, op.Column)
	if srcIdx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}

	var numVals []float64
	for _, row := range rows {
		if srcIdx < len(row) && row[srcIdx] != "" {
			v, err := strconv.ParseFloat(row[srcIdx], 64)
			if err == nil {
				numVals = append(numVals, v)
			}
		}
	}

	bins := op.Bins
	fmtF := func(v float64) string {
		return strconv.FormatFloat(v, 'f', -1, 64)
	}

	sorted := make([]float64, len(numVals))
	copy(sorted, numVals)
	sort.Float64s(sorted)

	var minV, maxV float64
	if len(sorted) > 0 {
		minV = sorted[0]
		maxV = sorted[len(sorted)-1]
	}

	type binBound struct {
		low, high float64
		last      bool
	}
	var binBounds []binBound

	if len(numVals) > 0 && minV != maxV {
		switch op.Method {
		case "width":
			w := (maxV - minV) / float64(bins)
			for i := 0; i < bins; i++ {
				low := minV + float64(i)*w
				high := minV + float64(i+1)*w
				if i == bins-1 {
					high = maxV
				}
				binBounds = append(binBounds, binBound{low, high, i == bins - 1})
			}

		case "quantile":
			boundaries := make([]float64, bins+1)
			for j := 0; j <= bins; j++ {
				pct := float64(j) * 100.0 / float64(bins)
				boundaries[j] = calcPercentile(sorted, pct)
			}
			for i := 0; i < bins; i++ {
				high := boundaries[i+1]
				if i == bins-1 {
					high = maxV
				}
				binBounds = append(binBounds, binBound{boundaries[i], high, i == bins - 1})
			}
		}
	}

	assignLabel := func(v float64) string {
		if len(numVals) == 0 {
			return ""
		}
		if minV == maxV {
			return "[" + fmtF(minV) + "," + fmtF(maxV) + "]"
		}

		switch op.Method {
		case "width":
			w := (maxV - minV) / float64(bins)
			idx := int(math.Floor((v - minV) / w))
			if idx >= bins {
				idx = bins - 1
			}
			if idx < 0 {
				idx = 0
			}
			b := binBounds[idx]
			if b.last {
				return "[" + fmtF(b.low) + "," + fmtF(b.high) + "]"
			}
			return "[" + fmtF(b.low) + "," + fmtF(b.high) + ")"

		case "quantile":
			idx := 0
			for i := 0; i < bins; i++ {
				if v >= binBounds[i].low {
					idx = i
				}
			}
			b := binBounds[idx]
			if b.last {
				return "[" + fmtF(b.low) + "," + fmtF(b.high) + "]"
			}
			return "[" + fmtF(b.low) + "," + fmtF(b.high) + ")"
		}
		return ""
	}

	newHeader := make([]string, len(header)+1)
	copy(newHeader, header)
	newHeader[len(header)] = op.As

	var newRows [][]string
	for _, row := range rows {
		newRow := make([]string, len(header)+1)
		copy(newRow, row)

		val := ""
		if srcIdx < len(row) {
			val = row[srcIdx]
		}

		label := ""
		if val != "" {
			_, err := strconv.ParseFloat(val, 64)
			if err == nil && len(numVals) > 0 {
				v, _ := strconv.ParseFloat(val, 64)
				label = assignLabel(v)
			}
		}
		newRow[len(header)] = label
		newRows = append(newRows, newRow)
	}

	return newHeader, newRows, nil
}
GOEOF

# Step 5: Create compare.go (with tolerance and ignore support)
cat > compare.go << 'GOEOF'
package main

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"sort"
	"strconv"
	"strings"
)

func readCSVFile(path string) ([]string, [][]string, error) {
	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil, fmt.Errorf("ERROR: file not found: %s", path)
		}
		return nil, nil, err
	}
	defer f.Close()

	r := csv.NewReader(f)
	r.FieldsPerRecord = -1
	records, err := r.ReadAll()
	if err != nil {
		return nil, nil, err
	}
	if len(records) == 0 {
		return nil, nil, nil
	}
	return records[0], records[1:], nil
}

func runCompare(args []string) error {
	p := parseArgs(args)
	leftPath := p["left"]
	rightPath := p["right"]
	keyStr := p["key"]
	outputPath := p["output"]
	toleranceStr := p["tolerance"]
	ignoreStr := p["ignore"]

	if keyStr == "" {
		return fmt.Errorf("ERROR: --key is required")
	}
	if outputPath == "" {
		return fmt.Errorf("ERROR: --output is required")
	}

	tolerance := 0.0
	if toleranceStr != "" {
		var err error
		tolerance, err = strconv.ParseFloat(toleranceStr, 64)
		if err != nil {
			tolerance = 0
		}
	}

	leftHeader, leftRows, err := readCSVFile(leftPath)
	if err != nil {
		return err
	}
	rightHeader, rightRows, err := readCSVFile(rightPath)
	if err != nil {
		return err
	}

	if len(leftHeader) != len(rightHeader) {
		return fmt.Errorf("ERROR: schema mismatch: headers differ")
	}
	for i := range leftHeader {
		if leftHeader[i] != rightHeader[i] {
			return fmt.Errorf("ERROR: schema mismatch: headers differ")
		}
	}

	header := leftHeader
	keyCols := strings.Split(keyStr, ",")
	var keyIndices []int
	keySet := make(map[int]bool)
	for _, k := range keyCols {
		found := false
		for i, h := range header {
			if h == k {
				keyIndices = append(keyIndices, i)
				keySet[i] = true
				found = true
				break
			}
		}
		if !found {
			return fmt.Errorf("ERROR: invalid key: column %s not found", k)
		}
	}

	ignoreSet := make(map[int]bool)
	if ignoreStr != "" {
		ignoreCols := strings.Split(ignoreStr, ",")
		for _, ic := range ignoreCols {
			found := false
			for i, h := range header {
				if h == ic {
					ignoreSet[i] = true
					found = true
					break
				}
			}
			if !found {
				return fmt.Errorf("ERROR: invalid ignore: column %s not found", ic)
			}
		}
	}

	makeKey := func(row []string) string {
		var parts []string
		for _, ki := range keyIndices {
			if ki < len(row) {
				parts = append(parts, row[ki])
			} else {
				parts = append(parts, "")
			}
		}
		return strings.Join(parts, "\x00")
	}

	makeKeyObj := func(row []string) map[string]string {
		obj := make(map[string]string)
		for _, ki := range keyIndices {
			if ki < len(row) {
				obj[header[ki]] = row[ki]
			} else {
				obj[header[ki]] = ""
			}
		}
		return obj
	}

	makeRowObj := func(row []string) map[string]string {
		obj := make(map[string]string)
		for i, h := range header {
			if i < len(row) {
				obj[h] = row[i]
			} else {
				obj[h] = ""
			}
		}
		return obj
	}

	valuesEqual := func(lv, rv string) bool {
		if lv == rv {
			return true
		}
		if tolerance > 0 {
			lf, errL := strconv.ParseFloat(lv, 64)
			rf, errR := strconv.ParseFloat(rv, 64)
			if errL == nil && errR == nil && math.Abs(lf-rf) <= tolerance {
				return true
			}
		}
		return false
	}

	leftMap := make(map[string][]string)
	for _, row := range leftRows {
		k := makeKey(row)
		if _, exists := leftMap[k]; !exists {
			leftMap[k] = row
		}
	}

	rightMap := make(map[string][]string)
	for _, row := range rightRows {
		k := makeKey(row)
		if _, exists := rightMap[k]; !exists {
			rightMap[k] = row
		}
	}

	type Change struct {
		Type  string            `json:"type"`
		Key   map[string]string `json:"key"`
		Row   map[string]string `json:"row,omitempty"`
		Left  map[string]string `json:"left,omitempty"`
		Right map[string]string `json:"right,omitempty"`
		Diff  []string          `json:"diff,omitempty"`
	}

	var changes []Change
	added := 0
	removed := 0
	modified := 0
	unchanged := 0

	for k, rRow := range rightMap {
		if _, exists := leftMap[k]; !exists {
			changes = append(changes, Change{
				Type: "added",
				Key:  makeKeyObj(rRow),
				Row:  makeRowObj(rRow),
			})
			added++
		}
	}

	for k, lRow := range leftMap {
		if _, exists := rightMap[k]; !exists {
			changes = append(changes, Change{
				Type: "removed",
				Key:  makeKeyObj(lRow),
				Row:  makeRowObj(lRow),
			})
			removed++
		} else {
			rRow := rightMap[k]
			var diffCols []string
			for i, h := range header {
				if keySet[i] || ignoreSet[i] {
					continue
				}
				lv := ""
				rv := ""
				if i < len(lRow) {
					lv = lRow[i]
				}
				if i < len(rRow) {
					rv = rRow[i]
				}
				if !valuesEqual(lv, rv) {
					diffCols = append(diffCols, h)
				}
			}
			if len(diffCols) > 0 {
				changes = append(changes, Change{
					Type:  "modified",
					Key:   makeKeyObj(lRow),
					Left:  makeRowObj(lRow),
					Right: makeRowObj(rRow),
					Diff:  diffCols,
				})
				modified++
			} else {
				unchanged++
			}
		}
	}

	typeOrder := map[string]int{"added": 0, "removed": 1, "modified": 2}
	sort.SliceStable(changes, func(i, j int) bool {
		ti := typeOrder[changes[i].Type]
		tj := typeOrder[changes[j].Type]
		if ti != tj {
			return ti < tj
		}
		ki := strings.Join(func() []string {
			var pp []string
			for _, idx := range keyIndices {
				if idx < len(header) {
					pp = append(pp, changes[i].Key[header[idx]])
				}
			}
			return pp
		}(), "\x00")
		kj := strings.Join(func() []string {
			var pp []string
			for _, idx := range keyIndices {
				if idx < len(header) {
					pp = append(pp, changes[j].Key[header[idx]])
				}
			}
			return pp
		}(), "\x00")
		return ki < kj
	})

	type Summary struct {
		LeftRows  int `json:"left_rows"`
		RightRows int `json:"right_rows"`
		Added     int `json:"added"`
		Removed   int `json:"removed"`
		Modified  int `json:"modified"`
		Unchanged int `json:"unchanged"`
	}

	type Output struct {
		Summary Summary  `json:"summary"`
		Changes []Change `json:"changes"`
	}

	if changes == nil {
		changes = []Change{}
	}

	output := Output{
		Summary: Summary{
			LeftRows:  len(leftRows),
			RightRows: len(rightRows),
			Added:     added,
			Removed:   removed,
			Modified:  modified,
			Unchanged: unchanged,
		},
		Changes: changes,
	}

	data, err := json.MarshalIndent(output, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(outputPath, append(data, '\n'), 0644)
}
GOEOF

# Step 6: Rebuild
go build -o dpipe ./...
