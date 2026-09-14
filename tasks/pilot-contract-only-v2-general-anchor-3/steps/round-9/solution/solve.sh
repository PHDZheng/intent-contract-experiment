#!/usr/bin/env bash
set -e

cd /app

# Step 1: Patch main.go - add schema command, mask transform, schema pipeline step
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

# Patch 1: Add "schema" command case before "quality"
code = code.replace(
    '\tcase "quality":\n\t\terr = runQuality(args)',
    '\tcase "schema":\n\t\terr = runSchema(args)\n\tcase "quality":\n\t\terr = runQuality(args)'
)

# Patch 2: Add "mask" transform case before "fill"
code = code.replace(
    '\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)',
    '\t\tcase "mask":\n\t\t\theader, rows, opErr = applyMask(header, rows, op)\n\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)'
)

# Patch 3: Add "schema" pipeline step before "quality"
code = code.replace(
    '\t\tcase "quality":\n\t\t\tstepErr = runQuality([]string{"--input", step.Input, "--output", step.Output})',
    '\t\tcase "schema":\n\t\t\tstepErr = runSchema([]string{"--input", step.Input, "--output", step.Output})\n\t\tcase "quality":\n\t\t\tstepErr = runQuality([]string{"--input", step.Input, "--output", step.Output})'
)

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 2: Patch lineage.go - add schema step support
python3 << 'PYEOF'
with open('lineage.go', 'r') as f:
    code = f.read()

# Add schema case before quality case in lineage
code = code.replace(
    '\t\tcase "quality":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")',
    '\t\tcase "schema":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")\n\t\tcase "quality":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")'
)

with open('lineage.go', 'w') as f:
    f.write(code)
PYEOF

# Step 3: Create schema.go
cat > schema.go << 'GOEOF'
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

func runSchema(args []string) error {
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
	if err != nil || len(records) == 0 {
		return fmt.Errorf("ERROR: empty CSV")
	}

	header := records[0]
	rows := records[1:]
	totalRows := len(rows)

	columnsMap := make(map[string]interface{})

	for colPos, colName := range header {
		var nonEmptyValues []string
		emptyCount := 0

		for _, row := range rows {
			if colPos < len(row) && row[colPos] != "" {
				nonEmptyValues = append(nonEmptyValues, row[colPos])
			} else {
				emptyCount++
			}
		}

		nonEmptyCount := len(nonEmptyValues)

		detectedType := "string"
		if nonEmptyCount > 0 {
			allInt := true
			for _, v := range nonEmptyValues {
				_, err := strconv.ParseInt(v, 10, 64)
				if err != nil {
					allInt = false
					break
				}
			}
			if allInt {
				detectedType = "int"
			} else {
				allFloat := true
				for _, v := range nonEmptyValues {
					_, err := strconv.ParseFloat(v, 64)
					if err != nil {
						allFloat = false
						break
					}
				}
				if allFloat {
					detectedType = "float"
				}
			}
		}

		constraint := make(map[string]interface{})
		constraint["type"] = detectedType

		if emptyCount == 0 && totalRows > 0 {
			constraint["required"] = true
		}

		if nonEmptyCount > 0 {
			uniqueSet := make(map[string]bool)
			for _, v := range nonEmptyValues {
				uniqueSet[v] = true
			}
			if len(uniqueSet) == nonEmptyCount {
				constraint["unique"] = true
			}
		}

		if detectedType == "int" && nonEmptyCount > 0 {
			var minVal, maxVal int64
			for i, v := range nonEmptyValues {
				iv, _ := strconv.ParseInt(v, 10, 64)
				if i == 0 {
					minVal = iv
					maxVal = iv
				} else {
					if iv < minVal {
						minVal = iv
					}
					if iv > maxVal {
						maxVal = iv
					}
				}
			}
			constraint["min"] = minVal
			constraint["max"] = maxVal
		} else if detectedType == "float" && nonEmptyCount > 0 {
			var minVal, maxVal float64
			minVal = math.Inf(1)
			maxVal = math.Inf(-1)
			for _, v := range nonEmptyValues {
				fv, _ := strconv.ParseFloat(v, 64)
				if fv < minVal {
					minVal = fv
				}
				if fv > maxVal {
					maxVal = fv
				}
			}
			constraint["min"] = minVal
			constraint["max"] = maxVal
		}

		if detectedType == "string" && nonEmptyCount > 0 {
			uniqueSet := make(map[string]bool)
			for _, v := range nonEmptyValues {
				uniqueSet[v] = true
			}
			if len(uniqueSet) <= 10 {
				var enumVals []string
				for v := range uniqueSet {
					enumVals = append(enumVals, v)
				}
				sort.Strings(enumVals)
				constraint["enum"] = enumVals
			}
		}

		columnsMap[colName] = constraint
	}

	output := map[string]interface{}{
		"columns": columnsMap,
		"strict":  false,
	}

	data, _ := json.MarshalIndent(output, "", "  ")
	return os.WriteFile(outputPath, append(data, '\n'), 0644)
}
GOEOF

# Step 4: Create transforms8.go (mask transform)
cat > transforms8.go << 'GOEOF'
package main

import (
	"crypto/sha256"
	"fmt"
)

func applyMask(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	colIdx := colIndex(header, op.Column)
	if colIdx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}

	newHeader := make([]string, len(header))
	copy(newHeader, header)
	newHeader = append(newHeader, op.As)

	var newRows [][]string
	for _, row := range rows {
		newRow := make([]string, len(row))
		copy(newRow, row)

		val := ""
		if colIdx < len(row) {
			val = row[colIdx]
		}

		masked := ""
		if val != "" {
			switch op.Method {
			case "full":
				masked = "****"
			case "partial":
				if len(val) <= 4 {
					masked = "****"
				} else {
					masked = val[:2] + "***" + val[len(val)-2:]
				}
			case "hash":
				h := sha256.Sum256([]byte(val))
				masked = fmt.Sprintf("%x", h)[:8]
			}
		}

		newRow = append(newRow, masked)
		newRows = append(newRows, newRow)
	}

	return newHeader, newRows, nil
}
GOEOF

# Step 5: Rebuild
go build -o dpipe ./...
