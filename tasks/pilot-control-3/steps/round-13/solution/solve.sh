#!/usr/bin/env bash
set -e

cd /app

# Step 1: Patch main.go - add snapshot command, clip transform, snapshot pipeline step
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

# Patch 1: Add "snapshot" command case before "reconcile"
code = code.replace(
    '\tcase "reconcile":\n\t\terr = runReconcile(args)',
    '\tcase "snapshot":\n\t\terr = runSnapshot(args)\n\tcase "reconcile":\n\t\terr = runReconcile(args)'
)

# Patch 2: Add "clip" transform case before "fill"
code = code.replace(
    '\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)',
    '\t\tcase "clip":\n\t\t\theader, rows, opErr = applyClip(header, rows, op)\n\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)'
)

# Patch 3: Add "snapshot" pipeline step before "schema"
code = code.replace(
    '\t\tcase "schema":\n\t\t\tstepErr = runSchema([]string{"--input", step.Input, "--output", step.Output})',
    '\t\tcase "snapshot":\n\t\t\tstepErr = runSnapshot([]string{"--input", step.Input, "--output", step.Output})\n\t\tcase "schema":\n\t\t\tstepErr = runSchema([]string{"--input", step.Input, "--output", step.Output})'
)

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 2: Patch lineage.go - add snapshot step support
python3 << 'PYEOF'
with open('lineage.go', 'r') as f:
    code = f.read()

code = code.replace(
    '\t\tcase "schema":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")',
    '\t\tcase "snapshot":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")\n\t\tcase "schema":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")'
)

with open('lineage.go', 'w') as f:
    f.write(code)
PYEOF

# Step 3: Create snapshot.go
cat > snapshot.go << 'GOEOF'
package main

import (
	"crypto/md5"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"os"
	"sort"
)

type ColumnStat struct {
	Name     string `json:"name"`
	NonEmpty int    `json:"non_empty"`
	Distinct int    `json:"distinct"`
}

type SnapshotResult struct {
	RowCount    int          `json:"row_count"`
	ColumnCount int          `json:"column_count"`
	Columns     []ColumnStat `json:"columns"`
	RowHash     string       `json:"row_hash"`
}

func runSnapshot(args []string) error {
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

	var colStats []ColumnStat
	for colPos, colName := range header {
		distinctSet := make(map[string]bool)
		nonEmpty := 0
		for _, row := range rows {
			if colPos < len(row) && row[colPos] != "" {
				nonEmpty++
				distinctSet[row[colPos]] = true
			}
		}
		colStats = append(colStats, ColumnStat{
			Name:     colName,
			NonEmpty: nonEmpty,
			Distinct: len(distinctSet),
		})
	}

	// Compute row_hash: sort rows lexicographically, join with newline, MD5
	var rowStrings []string
	for _, row := range rows {
		line := ""
		for i, val := range row {
			if i > 0 {
				line += ","
			}
			line += val
		}
		rowStrings = append(rowStrings, line)
	}
	sort.Strings(rowStrings)

	combined := ""
	for i, s := range rowStrings {
		if i > 0 {
			combined += "\n"
		}
		combined += s
	}

	hash := md5.Sum([]byte(combined))
	rowHash := fmt.Sprintf("%x", hash)

	result := SnapshotResult{
		RowCount:    len(rows),
		ColumnCount: len(header),
		Columns:     colStats,
		RowHash:     rowHash,
	}

	data, _ := json.MarshalIndent(result, "", "  ")
	return os.WriteFile(outputPath, append(data, '\n'), 0644)
}
GOEOF

# Step 4: Create transforms11.go (clip transform)
cat > transforms11.go << 'GOEOF'
package main

import (
	"fmt"
	"strconv"
)

func applyClip(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	srcIdx := colIndex(header, op.Column)
	if srcIdx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}

	minVal, err := strconv.ParseFloat(op.From, 64)
	if err != nil {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: invalid from value")
	}
	maxVal, err := strconv.ParseFloat(op.To, 64)
	if err != nil {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: invalid to value")
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
				if v < minVal {
					v = minVal
				} else if v > maxVal {
					v = maxVal
				}
				val = strconv.FormatFloat(v, 'f', -1, 64)
			}
		}
		newRow[len(header)] = val
		result = append(result, newRow)
	}
	return newHeader, result, nil
}
GOEOF

# Step 5: Build
go build -o dpipe ./...
