#!/usr/bin/env bash
set -e

cd /app

# Step 1: Patch main.go - add validate command, crossjoin/checkpoint transforms, pipeline step
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

# Patch 1: Add "validate" command case (before "drift")
code = code.replace(
    '\tcase "drift":\n\t\terr = runDrift(args)',
    '\tcase "validate":\n\t\terr = runValidate(args)\n\tcase "drift":\n\t\terr = runDrift(args)'
)

# Patch 2: Add "crossjoin" and "checkpoint" transform cases (before "resample")
code = code.replace(
    '\t\tcase "resample":\n\t\t\theader, rows, opErr = applyResample(header, rows, op)',
    '\t\tcase "crossjoin":\n\t\t\theader, rows, opErr = applyCrossjoin(header, rows, op)\n\t\tcase "checkpoint":\n\t\t\theader, rows, opErr = applyCheckpoint(header, rows, op)\n\t\tcase "resample":\n\t\t\theader, rows, opErr = applyResample(header, rows, op)'
)

# Patch 3: Add Algorithm field to TransformOp struct (after Key field)
code = code.replace(
    '\tKey          string        `json:"key,omitempty"`\n}',
    '\tKey          string        `json:"key,omitempty"`\n\tAlgorithm    string        `json:"algorithm,omitempty"`\n}'
)

# Patch 4: Add "validate" pipeline step (before "drift")
code = code.replace(
    '\t\tcase "drift":\n\t\t\tdriftArgs := []string{"--baseline", step.Baseline, "--current", step.Current, "--output", step.Output}',
    '\t\tcase "validate":\n\t\t\tstepErr = runValidate([]string{"--input", step.Input, "--schema", step.Schema, "--output", step.Output})\n\t\tcase "drift":\n\t\t\tdriftArgs := []string{"--baseline", step.Baseline, "--current", step.Current, "--output", step.Output}'
)

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 2: Create validate.go
cat > validate.go << 'GOEOF'
package main

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"
)

type ValColumnSchema struct {
	Type     string   `json:"type"`
	Required bool     `json:"required,omitempty"`
	Min      *float64 `json:"min,omitempty"`
	Max      *float64 `json:"max,omitempty"`
	Pattern  string   `json:"pattern,omitempty"`
	Unique   bool     `json:"unique,omitempty"`
	Enum     []string `json:"enum,omitempty"`
}

type ValSchema struct {
	Columns map[string]ValColumnSchema `json:"columns"`
	Strict  bool                       `json:"strict,omitempty"`
}

type Violation struct {
	Column  string      `json:"column"`
	Row     interface{} `json:"row"`
	Rule    string      `json:"rule"`
	Value   interface{} `json:"value"`
	Message string      `json:"message"`
}

type ValSummary struct {
	TotalViolations int `json:"total_violations"`
	ColumnsChecked  int `json:"columns_checked"`
	RowsChecked     int `json:"rows_checked"`
}

type ValReport struct {
	Valid      bool        `json:"valid"`
	Violations []Violation `json:"violations"`
	Summary    ValSummary  `json:"summary"`
}

func runValidate(args []string) error {
	p := parseArgs(args)
	inputPath := p["input"]
	schemaPath := p["schema"]
	outputPath := p["output"]

	if _, err := os.Stat(inputPath); os.IsNotExist(err) {
		return fmt.Errorf("ERROR: file not found: %s", inputPath)
	}
	if _, err := os.Stat(schemaPath); os.IsNotExist(err) {
		return fmt.Errorf("ERROR: file not found: %s", schemaPath)
	}

	schemaData, err := os.ReadFile(schemaPath)
	if err != nil {
		return fmt.Errorf("ERROR: file not found: %s", schemaPath)
	}

	var schema ValSchema
	if err := json.Unmarshal(schemaData, &schema); err != nil {
		return fmt.Errorf("ERROR: invalid schema: %s", schemaPath)
	}

	f, err := os.Open(inputPath)
	if err != nil {
		return fmt.Errorf("ERROR: file not found: %s", inputPath)
	}
	defer f.Close()

	reader := csv.NewReader(f)
	records, err := reader.ReadAll()
	if err != nil {
		return fmt.Errorf("ERROR: file not found: %s", inputPath)
	}

	if len(records) == 0 {
		report := ValReport{
			Valid:      true,
			Violations: []Violation{},
			Summary:    ValSummary{TotalViolations: 0, ColumnsChecked: 0, RowsChecked: 0},
		}
		data, _ := json.MarshalIndent(report, "", "  ")
		return os.WriteFile(outputPath, append(data, '\n'), 0644)
	}

	header := records[0]
	rows := records[1:]
	rowCount := len(rows)

	headerSet := make(map[string]bool)
	for _, h := range header {
		headerSet[h] = true
	}

	var violations []Violation
	columnsChecked := 0

	for _, colName := range header {
		colSchema, defined := schema.Columns[colName]
		if !defined {
			continue
		}
		columnsChecked++

		colIdx := -1
		for i, h := range header {
			if h == colName {
				colIdx = i
				break
			}
		}

		seen := make(map[string]int)

		for rowIdx, row := range rows {
			rowNum := rowIdx + 1
			val := ""
			if colIdx < len(row) {
				val = row[colIdx]
			}

			if val == "" {
				if colSchema.Required {
					violations = append(violations, Violation{
						Column:  colName,
						Row:     rowNum,
						Rule:    "required",
						Value:   nil,
						Message: "value is required",
					})
				}
				continue
			}

			typeValid := true
			var numVal float64
			switch colSchema.Type {
			case "int":
				_, err := strconv.ParseInt(val, 10, 64)
				if err != nil {
					typeValid = false
					violations = append(violations, Violation{
						Column:  colName,
						Row:     rowNum,
						Rule:    "type",
						Value:   val,
						Message: fmt.Sprintf("expected int, got \"%s\"", val),
					})
				} else {
					numVal, _ = strconv.ParseFloat(val, 64)
				}
			case "float":
				fv, err := strconv.ParseFloat(val, 64)
				if err != nil {
					typeValid = false
					violations = append(violations, Violation{
						Column:  colName,
						Row:     rowNum,
						Rule:    "type",
						Value:   val,
						Message: fmt.Sprintf("expected float, got \"%s\"", val),
					})
				} else {
					numVal = fv
				}
			case "string":
				// always valid
			}

			if typeValid && (colSchema.Type == "int" || colSchema.Type == "float") {
				if colSchema.Min != nil && numVal < *colSchema.Min {
					violations = append(violations, Violation{
						Column:  colName,
						Row:     rowNum,
						Rule:    "min",
						Value:   val,
						Message: fmt.Sprintf("value %s is below minimum %v", val, *colSchema.Min),
					})
				}
				if colSchema.Max != nil && numVal > *colSchema.Max {
					violations = append(violations, Violation{
						Column:  colName,
						Row:     rowNum,
						Rule:    "max",
						Value:   val,
						Message: fmt.Sprintf("value %s exceeds maximum %v", val, *colSchema.Max),
					})
				}
			}

			if colSchema.Type == "string" && colSchema.Pattern != "" {
				matched, _ := regexp.MatchString(colSchema.Pattern, val)
				if !matched {
					violations = append(violations, Violation{
						Column:  colName,
						Row:     rowNum,
						Rule:    "pattern",
						Value:   val,
						Message: fmt.Sprintf("value \"%s\" does not match pattern %s", val, colSchema.Pattern),
					})
				}
			}

			if len(colSchema.Enum) > 0 {
				found := false
				for _, e := range colSchema.Enum {
					if val == e {
						found = true
						break
					}
				}
				if !found {
					enumStr := strings.Join(colSchema.Enum, ", ")
					violations = append(violations, Violation{
						Column:  colName,
						Row:     rowNum,
						Rule:    "enum",
						Value:   val,
						Message: fmt.Sprintf("value \"%s\" is not in allowed values [%s]", val, enumStr),
					})
				}
			}

			if colSchema.Unique {
				if firstRow, exists := seen[val]; exists {
					violations = append(violations, Violation{
						Column:  colName,
						Row:     nil,
						Rule:    "unique",
						Value:   val,
						Message: fmt.Sprintf("duplicate value \"%s\" (first at row %d, repeated at row %d)", val, firstRow, rowNum),
					})
				} else {
					seen[val] = rowNum
				}
			}
		}
	}

	// column_missing
	for colName := range schema.Columns {
		if !headerSet[colName] {
			violations = append(violations, Violation{
				Column:  colName,
				Row:     nil,
				Rule:    "column_missing",
				Value:   nil,
				Message: fmt.Sprintf("column \"%s\" defined in schema but missing from data", colName),
			})
		}
	}

	// strict
	if schema.Strict {
		for _, colName := range header {
			if _, defined := schema.Columns[colName]; !defined {
				violations = append(violations, Violation{
					Column:  colName,
					Row:     nil,
					Rule:    "strict",
					Value:   nil,
					Message: fmt.Sprintf("column \"%s\" not defined in schema", colName),
				})
			}
		}
	}

	if violations == nil {
		violations = []Violation{}
	}

	report := ValReport{
		Valid:      len(violations) == 0,
		Violations: violations,
		Summary: ValSummary{
			TotalViolations: len(violations),
			ColumnsChecked:  columnsChecked,
			RowsChecked:     rowCount,
		},
	}

	data, _ := json.MarshalIndent(report, "", "  ")
	return os.WriteFile(outputPath, append(data, '\n'), 0644)
}
GOEOF

# Step 3: Create transforms5.go (crossjoin, checkpoint)
cat > transforms5.go << 'GOEOF'
package main

import (
	"crypto/sha256"
	"encoding/csv"
	"encoding/hex"
	"fmt"
	"os"
	"strconv"
	"strings"
)

func applyCrossjoin(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	rightPath := op.Right
	if _, err := os.Stat(rightPath); os.IsNotExist(err) {
		return nil, nil, fmt.Errorf("ERROR: file not found: %s", rightPath)
	}

	f, err := os.Open(rightPath)
	if err != nil {
		return nil, nil, fmt.Errorf("ERROR: file not found: %s", rightPath)
	}
	defer f.Close()

	reader := csv.NewReader(f)
	records, err := reader.ReadAll()
	if err != nil {
		return nil, nil, fmt.Errorf("ERROR: file not found: %s", rightPath)
	}

	if len(records) == 0 {
		return header, nil, nil
	}

	rightHeader := records[0]
	rightRows := records[1:]

	// Determine which right columns to include
	var rightCols []string
	if len(op.Columns) > 0 {
		rightCols = op.Columns
	} else {
		rightCols = rightHeader
	}

	// Validate columns exist in right header
	rightHeaderSet := make(map[string]int)
	for i, h := range rightHeader {
		rightHeaderSet[h] = i
	}
	var rightIndices []int
	for _, col := range rightCols {
		idx, exists := rightHeaderSet[col]
		if !exists {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", col)
		}
		rightIndices = append(rightIndices, idx)
	}

	// Build output header
	newHeader := make([]string, len(header)+len(rightCols))
	copy(newHeader, header)
	for i, col := range rightCols {
		newHeader[len(header)+i] = col
	}

	// Cartesian product
	var newRows [][]string
	for _, leftRow := range rows {
		for _, rightRow := range rightRows {
			newRow := make([]string, len(header)+len(rightCols))
			copy(newRow, leftRow)
			for i, idx := range rightIndices {
				if idx < len(rightRow) {
					newRow[len(header)+i] = rightRow[idx]
				}
			}
			newRows = append(newRows, newRow)
		}
	}

	return newHeader, newRows, nil
}

func applyCheckpoint(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	newHeader := make([]string, len(header)+1)
	copy(newHeader, header)
	newHeader[len(header)] = op.As

	var newRows [][]string
	for i, row := range rows {
		newRow := make([]string, len(row)+1)
		copy(newRow, row)

		switch op.Algorithm {
		case "row_hash":
			input := strings.Join(row, "|")
			h := sha256.Sum256([]byte(input))
			newRow[len(row)] = hex.EncodeToString(h[:4])
		case "row_number":
			newRow[len(row)] = strconv.Itoa(i + 1)
		}

		newRows = append(newRows, newRow)
	}

	return newHeader, newRows, nil
}
GOEOF

# Step 4: Rebuild
go build -o dpipe ./...
