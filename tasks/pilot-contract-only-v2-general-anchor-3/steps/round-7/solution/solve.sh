#!/usr/bin/env bash
set -e

cd /app

# Step 1: Patch lineage.go - fix manifest step to have no inputs
python3 << 'PYEOF'
with open('lineage.go', 'r') as f:
    code = f.read()

# Change manifest case: no inputs instead of dir as input
code = code.replace(
    '\t\tcase "manifest":\n\t\t\tinputs = []string{getStr(step, "dir")}\n\t\t\toutput = getStr(step, "output")',
    '\t\tcase "manifest":\n\t\t\tinputs = []string{}\n\t\t\toutput = getStr(step, "output")'
)

with open('lineage.go', 'w') as f:
    f.write(code)
PYEOF

# Step 2: Patch main.go - add temporal transform case (before "impute")
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

code = code.replace(
    '\t\tcase "impute":\n\t\t\theader, rows, opErr = applyImpute(header, rows, op)',
    '\t\tcase "temporal":\n\t\t\theader, rows, opErr = applyTemporal(header, rows, op)\n\t\tcase "impute":\n\t\t\theader, rows, opErr = applyImpute(header, rows, op)'
)

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 3: Create transforms7.go (temporal)
cat > transforms7.go << 'GOEOF'
package main

import (
	"fmt"
	"strconv"
)

func applyTemporal(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	srcIdx := colIndex(header, op.Column)
	if srcIdx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}

	newHeader := make([]string, len(header)+1)
	copy(newHeader, header)
	newHeader[len(header)] = op.As

	var newRows [][]string

	switch op.Function {
	case "diff":
		hasPrev := false
		prevVal := 0.0
		for _, row := range rows {
			newRow := make([]string, len(row)+1)
			copy(newRow, row)

			val := ""
			if srcIdx < len(row) {
				val = row[srcIdx]
			}

			if val == "" {
				newRow[len(row)] = ""
				hasPrev = false
			} else {
				curVal, err := strconv.ParseFloat(val, 64)
				if err != nil {
					newRow[len(row)] = ""
					hasPrev = false
				} else {
					if hasPrev {
						newRow[len(row)] = formatFloat(curVal - prevVal)
					} else {
						newRow[len(row)] = ""
					}
					prevVal = curVal
					hasPrev = true
				}
			}
			newRows = append(newRows, newRow)
		}

	case "cumsum":
		cumSum := 0.0
		for _, row := range rows {
			newRow := make([]string, len(row)+1)
			copy(newRow, row)

			val := ""
			if srcIdx < len(row) {
				val = row[srcIdx]
			}

			if val == "" {
				newRow[len(row)] = ""
			} else {
				curVal, err := strconv.ParseFloat(val, 64)
				if err != nil {
					newRow[len(row)] = ""
				} else {
					cumSum += curVal
					newRow[len(row)] = formatFloat(cumSum)
				}
			}
			newRows = append(newRows, newRow)
		}

	case "pct_change":
		hasPrev := false
		prevVal := 0.0
		for _, row := range rows {
			newRow := make([]string, len(row)+1)
			copy(newRow, row)

			val := ""
			if srcIdx < len(row) {
				val = row[srcIdx]
			}

			if val == "" {
				newRow[len(row)] = ""
				hasPrev = false
			} else {
				curVal, err := strconv.ParseFloat(val, 64)
				if err != nil {
					newRow[len(row)] = ""
					hasPrev = false
				} else {
					if hasPrev {
						if prevVal == 0 {
							newRow[len(row)] = ""
						} else {
							newRow[len(row)] = formatFloat((curVal - prevVal) / prevVal)
						}
					} else {
						newRow[len(row)] = ""
					}
					prevVal = curVal
					hasPrev = true
				}
			}
			newRows = append(newRows, newRow)
		}
	}

	return newHeader, newRows, nil
}
GOEOF

# Step 4: Rebuild
go build -o dpipe ./...
