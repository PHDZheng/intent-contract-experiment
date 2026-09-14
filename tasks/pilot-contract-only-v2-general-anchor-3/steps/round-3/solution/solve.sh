#!/usr/bin/env bash
set -e

cd /app

# Step 1: Patch transforms2.go - fix fill linear boundary extrapolation + normalize zscore sample stddev
python3 << 'PYEOF'
with open('transforms2.go', 'r') as f:
    code = f.read()

old = '''			if lowerIdx >= 0 && upperIdx >= 0 {
				frac := float64(i-lowerIdx) / float64(upperIdx-lowerIdx)
				result := lowerVal + (upperVal-lowerVal)*frac
				rows[i][ci] = formatFloat(result)
			}'''

new = '''			if lowerIdx >= 0 && upperIdx >= 0 {
				frac := float64(i-lowerIdx) / float64(upperIdx-lowerIdx)
				result := lowerVal + (upperVal-lowerVal)*frac
				rows[i][ci] = formatFloat(result)
			} else if lowerIdx >= 0 {
				rows[i][ci] = formatFloat(lowerVal)
			} else if upperIdx >= 0 {
				rows[i][ci] = formatFloat(upperVal)
			}'''

code = code.replace(old, new)

# Normalize zscore: change population stddev to sample stddev
code = code.replace(
    'stddev = math.Sqrt(sumSqDiff / float64(n))',
    'if n < 2 {\n\t\tstddev = 0\n\t} else {\n\t\tstddev = math.Sqrt(sumSqDiff / float64(n-1))\n\t}'
)

with open('transforms2.go', 'w') as f:
    f.write(code)
PYEOF

# Step 2: Patch profile.go - add p05 and p95 percentiles
python3 << 'PYEOF'
with open('profile.go', 'r') as f:
    code = f.read()

code = code.replace(
    '\t\tprofile["p25"] = calcPercentile(floatVals, 25)',
    '\t\tprofile["p05"] = calcPercentile(floatVals, 5)\n\t\tprofile["p25"] = calcPercentile(floatVals, 25)'
)
code = code.replace(
    '\t\tprofile["p75"] = calcPercentile(floatVals, 75)',
    '\t\tprofile["p75"] = calcPercentile(floatVals, 75)\n\t\tprofile["p95"] = calcPercentile(floatVals, 95)'
)

with open('profile.go', 'w') as f:
    f.write(code)
PYEOF

# Step 3: Patch main.go - add drift command, new transforms, pipeline step
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

# Patch 1: Add Seed and Key fields to TransformOp struct
code = code.replace(
    '\tBins         int           `json:"bins,omitempty"`\n}',
    '\tBins         int           `json:"bins,omitempty"`\n\tSeed         int           `json:"seed,omitempty"`\n\tKey          string        `json:"key,omitempty"`\n}'
)

# Patch 2: Add "drift" command case (before "pipeline")
code = code.replace(
    '\tcase "pipeline":\n\t\terr = runPipeline(args)',
    '\tcase "drift":\n\t\terr = runDrift(args)\n\tcase "pipeline":\n\t\terr = runPipeline(args)'
)

# Patch 3: Add resample and watermark transform cases (before "fill")
code = code.replace(
    '\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)',
    '\t\tcase "resample":\n\t\t\theader, rows, opErr = applyResample(header, rows, op)\n\t\tcase "watermark":\n\t\t\theader, rows, opErr = applyWatermark(header, rows, op)\n\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)'
)

# Patch 4: Add Baseline, Current, Threshold fields to PipelineStep struct
code = code.replace(
    '\tKey      string `json:"key,omitempty"`\n}',
    '\tKey       string  `json:"key,omitempty"`\n\tBaseline  string  `json:"baseline,omitempty"`\n\tCurrent   string  `json:"current,omitempty"`\n\tThreshold float64 `json:"threshold,omitempty"`\n}'
)

# Patch 5: Add "drift" pipeline step (before "manifest")
code = code.replace(
    '\t\tcase "manifest":\n\t\t\tstepErr = runManifest([]string{"--dir", step.Dir, "--output", step.Output})',
    '\t\tcase "drift":\n\t\t\tdriftArgs := []string{"--baseline", step.Baseline, "--current", step.Current, "--output", step.Output}\n\t\t\tif step.Threshold > 0 {\n\t\t\t\tdriftArgs = append(driftArgs, "--threshold", fmt.Sprintf("%g", step.Threshold))\n\t\t\t}\n\t\t\tstepErr = runDrift(driftArgs)\n\t\tcase "manifest":\n\t\t\tstepErr = runManifest([]string{"--dir", step.Dir, "--output", step.Output})'
)

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 4: Create drift.go (reads CSV files, profiles internally, compares)
cat > drift.go << 'GOEOF'
package main

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"sort"
	"strconv"
)

type colProfile struct {
	Name      string
	Type      string
	Count     int
	NullCount int
	Unique    int
	Min       float64
	Max       float64
	Mean      float64
	Stddev    float64
}

type csvProfile struct {
	RowCount int
	Columns  []colProfile
}

func profileCSV(path string) (*csvProfile, error) {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return nil, fmt.Errorf("ERROR: file not found: %s", path)
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("ERROR: file not found: %s", path)
	}
	defer f.Close()

	reader := csv.NewReader(f)
	records, err := reader.ReadAll()
	if err != nil {
		return nil, fmt.Errorf("ERROR: cannot parse CSV: %s", path)
	}
	if len(records) == 0 {
		return &csvProfile{RowCount: 0}, nil
	}

	header := records[0]
	rows := records[1:]
	rowCount := len(rows)

	var cols []colProfile
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
		var floatVals []float64

		if count > 0 {
			allInt := true
			for _, v := range values {
				_, err := strconv.ParseInt(v, 10, 64)
				if err != nil {
					allInt = false
					break
				}
			}
			if allInt {
				colType = "int"
				for _, v := range values {
					iv, _ := strconv.ParseInt(v, 10, 64)
					floatVals = append(floatVals, float64(iv))
				}
			} else {
				allFloat := true
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
					colType = "string"
				}
			}
		}

		cp := colProfile{
			Name:      colName,
			Type:      colType,
			Count:     count,
			NullCount: nullCount,
			Unique:    unique,
		}

		if (colType == "int" || colType == "float") && count > 0 {
			sort.Float64s(floatVals)
			cp.Min = floatVals[0]
			cp.Max = floatVals[len(floatVals)-1]

			sum := 0.0
			for _, v := range floatVals {
				sum += v
			}
			n := float64(count)
			cp.Mean = sum / n

			sumSqDiff := 0.0
			for _, v := range floatVals {
				d := v - cp.Mean
				sumSqDiff += d * d
			}
			cp.Stddev = math.Sqrt(sumSqDiff / n)
		}

		cols = append(cols, cp)
	}

	return &csvProfile{RowCount: rowCount, Columns: cols}, nil
}

type DriftEntry struct {
	Column        string      `json:"column"`
	DriftType     string      `json:"drift_type"`
	BaselineValue interface{} `json:"baseline_value"`
	CurrentValue  interface{} `json:"current_value"`
	Detail        string      `json:"detail"`
}

type DriftSummary struct {
	TotalDrifts        int `json:"total_drifts"`
	SchemaDrifts       int `json:"schema_drifts"`
	DistributionDrifts int `json:"distribution_drifts"`
}

type DriftReport struct {
	Drifts  []DriftEntry `json:"drifts"`
	Summary DriftSummary `json:"summary"`
}

var driftTypeOrder = map[string]int{
	"column_added":        0,
	"column_removed":      1,
	"type_changed":        2,
	"mean_shift":          3,
	"null_rate_change":    4,
	"range_expansion":     5,
	"unique_ratio_change": 6,
}

func runDrift(args []string) error {
	p := parseArgs(args)
	baselinePath := p["baseline"]
	currentPath := p["current"]
	outputPath := p["output"]
	thresholdStr := p["threshold"]

	threshold := 0.1
	if thresholdStr != "" {
		t, err := strconv.ParseFloat(thresholdStr, 64)
		if err == nil && t > 0 {
			threshold = t
		}
	}

	baseProfile, err := profileCSV(baselinePath)
	if err != nil {
		return err
	}
	curProfile, err := profileCSV(currentPath)
	if err != nil {
		return err
	}

	baseMap := make(map[string]colProfile)
	for _, col := range baseProfile.Columns {
		baseMap[col.Name] = col
	}
	curMap := make(map[string]colProfile)
	for _, col := range curProfile.Columns {
		curMap[col.Name] = col
	}

	allCols := make(map[string]bool)
	for name := range baseMap {
		allCols[name] = true
	}
	for name := range curMap {
		allCols[name] = true
	}

	var drifts []DriftEntry
	schemaDrifts := 0
	distDrifts := 0

	for colName := range allCols {
		basCol, inBase := baseMap[colName]
		curCol, inCur := curMap[colName]

		if !inBase && inCur {
			drifts = append(drifts, DriftEntry{
				Column:        colName,
				DriftType:     "column_added",
				BaselineValue: nil,
				CurrentValue:  curCol.Type,
				Detail:        fmt.Sprintf("new column of type %s", curCol.Type),
			})
			schemaDrifts++
			continue
		}

		if inBase && !inCur {
			drifts = append(drifts, DriftEntry{
				Column:        colName,
				DriftType:     "column_removed",
				BaselineValue: basCol.Type,
				CurrentValue:  nil,
				Detail:        fmt.Sprintf("column of type %s removed", basCol.Type),
			})
			schemaDrifts++
			continue
		}

		if basCol.Type != curCol.Type {
			drifts = append(drifts, DriftEntry{
				Column:        colName,
				DriftType:     "type_changed",
				BaselineValue: basCol.Type,
				CurrentValue:  curCol.Type,
				Detail:        fmt.Sprintf("type changed from %s to %s", basCol.Type, curCol.Type),
			})
			schemaDrifts++
			continue
		}

		if (basCol.Type == "int" || basCol.Type == "float") && basCol.Count > 0 && curCol.Count > 0 {
			normalizedShift := math.Abs(curCol.Mean-basCol.Mean) / math.Max(basCol.Stddev, 1e-10)
			if normalizedShift > threshold {
				drifts = append(drifts, DriftEntry{
					Column:        colName,
					DriftType:     "mean_shift",
					BaselineValue: basCol.Mean,
					CurrentValue:  curCol.Mean,
					Detail:        fmt.Sprintf("normalized shift = %v", normalizedShift),
				})
				distDrifts++
			}

			basNullRate := 0.0
			if baseProfile.RowCount > 0 {
				basNullRate = float64(basCol.NullCount) / float64(baseProfile.RowCount)
			}
			curNullRate := 0.0
			if curProfile.RowCount > 0 {
				curNullRate = float64(curCol.NullCount) / float64(curProfile.RowCount)
			}
			if math.Abs(curNullRate-basNullRate) > threshold {
				drifts = append(drifts, DriftEntry{
					Column:        colName,
					DriftType:     "null_rate_change",
					BaselineValue: basNullRate,
					CurrentValue:  curNullRate,
					Detail:        fmt.Sprintf("null rate changed from %v to %v", basNullRate, curNullRate),
				})
				distDrifts++
			}

			basRange := basCol.Max - basCol.Min
			curRange := curCol.Max - curCol.Min
			if curRange > basRange*(1+threshold) {
				drifts = append(drifts, DriftEntry{
					Column:        colName,
					DriftType:     "range_expansion",
					BaselineValue: basRange,
					CurrentValue:  curRange,
					Detail:        fmt.Sprintf("range expanded from %v to %v", basRange, curRange),
				})
				distDrifts++
			}

			basUniqueRatio := 0.0
			if basCol.Count > 0 {
				basUniqueRatio = float64(basCol.Unique) / float64(basCol.Count)
			}
			curUniqueRatio := 0.0
			if curCol.Count > 0 {
				curUniqueRatio = float64(curCol.Unique) / float64(curCol.Count)
			}
			if math.Abs(curUniqueRatio-basUniqueRatio) > threshold {
				drifts = append(drifts, DriftEntry{
					Column:        colName,
					DriftType:     "unique_ratio_change",
					BaselineValue: basUniqueRatio,
					CurrentValue:  curUniqueRatio,
					Detail:        fmt.Sprintf("unique ratio changed from %v to %v", basUniqueRatio, curUniqueRatio),
				})
				distDrifts++
			}
		}
	}

	sort.Slice(drifts, func(i, j int) bool {
		if drifts[i].Column != drifts[j].Column {
			return drifts[i].Column < drifts[j].Column
		}
		return driftTypeOrder[drifts[i].DriftType] < driftTypeOrder[drifts[j].DriftType]
	})

	if drifts == nil {
		drifts = []DriftEntry{}
	}

	report := DriftReport{
		Drifts: drifts,
		Summary: DriftSummary{
			TotalDrifts:        schemaDrifts + distDrifts,
			SchemaDrifts:       schemaDrifts,
			DistributionDrifts: distDrifts,
		},
	}

	data, _ := json.MarshalIndent(report, "", "  ")
	return os.WriteFile(outputPath, append(data, '\n'), 0644)
}
GOEOF

# Step 5: Create transforms4.go (resample, watermark)
cat > transforms4.go << 'GOEOF'
package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math/rand"
	"sort"
	"strings"
)

func applyResample(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	srcIdx := colIndex(header, op.Column)
	if srcIdx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}

	type group struct {
		key  string
		rows [][]string
	}

	groupMap := make(map[string]*group)
	var groupKeys []string
	for _, row := range rows {
		val := ""
		if srcIdx < len(row) {
			val = row[srcIdx]
		}
		g, exists := groupMap[val]
		if !exists {
			g = &group{key: val}
			groupMap[val] = g
			groupKeys = append(groupKeys, val)
		}
		g.rows = append(g.rows, row)
	}

	sort.Strings(groupKeys)

	switch op.Strategy {
	case "oversample":
		maxSize := 0
		for _, key := range groupKeys {
			if len(groupMap[key].rows) > maxSize {
				maxSize = len(groupMap[key].rows)
			}
		}

		var result [][]string
		for _, key := range groupKeys {
			g := groupMap[key]
			origLen := len(g.rows)
			for _, r := range g.rows {
				result = append(result, r)
			}
			for i := origLen; i < maxSize; i++ {
				result = append(result, g.rows[i%origLen])
			}
		}

		return header, result, nil

	case "undersample":
		minSize := len(rows) + 1
		for _, key := range groupKeys {
			if len(groupMap[key].rows) < minSize {
				minSize = len(groupMap[key].rows)
			}
		}

		var result [][]string
		for gi, key := range groupKeys {
			g := groupMap[key]
			if len(g.rows) <= minSize {
				result = append(result, g.rows...)
			} else {
				indices := make([]int, len(g.rows))
				for i := range indices {
					indices[i] = i
				}
				rng := rand.New(rand.NewSource(int64(op.Seed + gi)))
				for i := len(indices) - 1; i >= 1; i-- {
					j := rng.Intn(i + 1)
					indices[i], indices[j] = indices[j], indices[i]
				}
				selected := make([]int, minSize)
				copy(selected, indices[:minSize])
				sort.Ints(selected)
				for _, idx := range selected {
					result = append(result, g.rows[idx])
				}
			}
		}

		return header, result, nil
	}

	return header, rows, nil
}

func applyWatermark(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
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
		mac := hmac.New(sha256.New, []byte(op.Key))
		mac.Write([]byte(input))
		digest := mac.Sum(nil)
		wmStr := hex.EncodeToString(digest[:8])

		newRow := make([]string, len(row)+1)
		copy(newRow, row)
		newRow[len(row)] = wmStr
		newRows = append(newRows, newRow)
	}

	return newHeader, newRows, nil
}
GOEOF

# Step 6: Rebuild
go build -o dpipe ./...
