#!/usr/bin/env bash
set -e

cd /app

# Step 1: Patch main.go - add changelog command, scale transform, changelog pipeline step
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

# Patch 1: Add "changelog" command case before "reconcile"
code = code.replace(
    '\tcase "reconcile":\n\t\terr = runReconcile(args)',
    '\tcase "changelog":\n\t\terr = runChangelog(args)\n\tcase "reconcile":\n\t\terr = runReconcile(args)'
)

# Patch 2: Add "scale" transform case before "fill"
code = code.replace(
    '\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)',
    '\t\tcase "scale":\n\t\t\theader, rows, opErr = applyScale(header, rows, op)\n\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)'
)

# Patch 3: Add "changelog" pipeline step before "schema"
code = code.replace(
    '\t\tcase "schema":\n\t\t\tstepErr = runSchema([]string{"--input", step.Input, "--output", step.Output})',
    '\t\tcase "changelog":\n\t\t\tstepErr = runChangelog([]string{"--before", step.Input, "--after", step.Right, "--output", step.Output})\n\t\tcase "schema":\n\t\t\tstepErr = runSchema([]string{"--input", step.Input, "--output", step.Output})'
)

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 2: Patch lineage.go - add changelog step support
python3 << 'PYEOF'
with open('lineage.go', 'r') as f:
    code = f.read()

code = code.replace(
    '\t\tcase "schema":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")',
    '\t\tcase "changelog":\n\t\t\tinputs = []string{getStr(step, "input"), getStr(step, "right")}\n\t\t\toutput = getStr(step, "output")\n\t\tcase "schema":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")'
)

with open('lineage.go', 'w') as f:
    f.write(code)
PYEOF

# Step 3: Create changelog.go
cat > changelog.go << 'GOEOF'
package main

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"os"
)

type ChangelogResult struct {
	RowsBefore     int      `json:"rows_before"`
	RowsAfter      int      `json:"rows_after"`
	ColumnsBefore  []string `json:"columns_before"`
	ColumnsAfter   []string `json:"columns_after"`
	ColumnsAdded   []string `json:"columns_added"`
	ColumnsRemoved []string `json:"columns_removed"`
	RowCountChange int      `json:"row_count_change"`
}

func runChangelog(args []string) error {
	p := parseArgs(args)
	beforePath := p["before"]
	afterPath := p["after"]
	outputPath := p["output"]

	// Check before file exists
	if _, err := os.Stat(beforePath); os.IsNotExist(err) {
		return fmt.Errorf("ERROR: file not found: %s", beforePath)
	}

	// Check after file exists
	if _, err := os.Stat(afterPath); os.IsNotExist(err) {
		return fmt.Errorf("ERROR: file not found: %s", afterPath)
	}

	// Read before file
	bf, err := os.Open(beforePath)
	if err != nil {
		return fmt.Errorf("ERROR: file not found: %s", beforePath)
	}
	defer bf.Close()

	breader := csv.NewReader(bf)
	brecords, err := breader.ReadAll()
	if err != nil {
		return fmt.Errorf("ERROR: cannot parse before file")
	}

	// Read after file
	af, err := os.Open(afterPath)
	if err != nil {
		return fmt.Errorf("ERROR: file not found: %s", afterPath)
	}
	defer af.Close()

	areader := csv.NewReader(af)
	arecords, err := areader.ReadAll()
	if err != nil {
		return fmt.Errorf("ERROR: cannot parse after file")
	}

	var beforeHeader []string
	var afterHeader []string
	rowsBefore := 0
	rowsAfter := 0

	if len(brecords) > 0 {
		beforeHeader = brecords[0]
		rowsBefore = len(brecords) - 1
	}
	if len(arecords) > 0 {
		afterHeader = arecords[0]
		rowsAfter = len(arecords) - 1
	}

	// Compute columns_added: in after but not in before
	beforeSet := make(map[string]bool)
	for _, c := range beforeHeader {
		beforeSet[c] = true
	}
	afterSet := make(map[string]bool)
	for _, c := range afterHeader {
		afterSet[c] = true
	}

	columnsAdded := []string{}
	for _, c := range afterHeader {
		if !beforeSet[c] {
			columnsAdded = append(columnsAdded, c)
		}
	}

	columnsRemoved := []string{}
	for _, c := range beforeHeader {
		if !afterSet[c] {
			columnsRemoved = append(columnsRemoved, c)
		}
	}

	result := ChangelogResult{
		RowsBefore:     rowsBefore,
		RowsAfter:      rowsAfter,
		ColumnsBefore:  beforeHeader,
		ColumnsAfter:   afterHeader,
		ColumnsAdded:   columnsAdded,
		ColumnsRemoved: columnsRemoved,
		RowCountChange: rowsAfter - rowsBefore,
	}

	out, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(outputPath, out, 0644)
}
GOEOF

# Step 4: Create transforms12.go for applyScale
cat > transforms12.go << 'GOEOF'
package main

import (
	"fmt"
	"strconv"
)

func applyScale(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	colIdx := -1
	for i, h := range header {
		if h == op.Column {
			colIdx = i
			break
		}
	}
	if colIdx == -1 {
		return header, rows, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}

	newHeader := make([]string, len(header))
	copy(newHeader, header)
	newHeader = append(newHeader, op.As)

	var newRows [][]string
	for _, row := range rows {
		newRow := make([]string, len(row))
		copy(newRow, row)

		cell := ""
		if colIdx < len(row) {
			cell = row[colIdx]
		}

		if cell == "" {
			newRow = append(newRow, "")
		} else {
			val, err := strconv.ParseFloat(cell, 64)
			if err != nil {
				newRow = append(newRow, "")
			} else {
				result := val * op.Factor
				newRow = append(newRow, strconv.FormatFloat(result, 'f', -1, 64))
			}
		}
		newRows = append(newRows, newRow)
	}

	return newHeader, newRows, nil
}
GOEOF

# Step 5: Build
go build -o dpipe ./...
