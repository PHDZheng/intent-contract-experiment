#!/usr/bin/env bash
set -e

cd /app

# Step 1: Patch main.go - add quality command, pipeline step, lineage step
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

# Patch 1: Add "quality" command case (before "pipeline")
code = code.replace(
    '\tcase "pipeline":\n\t\terr = runPipeline(args)',
    '\tcase "quality":\n\t\terr = runQuality(args)\n\tcase "pipeline":\n\t\terr = runPipeline(args)'
)

# Patch 2: Add "quality" pipeline step (before "manifest")
code = code.replace(
    '\t\tcase "manifest":\n\t\t\tstepErr = runManifest([]string{"--dir", step.Dir, "--output", step.Output})',
    '\t\tcase "quality":\n\t\t\tstepErr = runQuality([]string{"--input", step.Input, "--output", step.Output})\n\t\tcase "manifest":\n\t\t\tstepErr = runManifest([]string{"--dir", step.Dir, "--output", step.Output})'
)

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 2: Patch lineage.go - add quality step support
python3 << 'PYEOF'
with open('lineage.go', 'r') as f:
    code = f.read()

# Add quality case before manifest case in lineage
code = code.replace(
    '\t\tcase "manifest":\n\t\t\tinputs = []string{}\n\t\t\toutput = getStr(step, "output")',
    '\t\tcase "quality":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")\n\t\tcase "manifest":\n\t\t\tinputs = []string{}\n\t\t\toutput = getStr(step, "output")'
)

with open('lineage.go', 'w') as f:
    f.write(code)
PYEOF

# Step 3: Create quality.go
cat > quality.go << 'GOEOF'
package main

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
)

type QualityColumn struct {
	Name         string  `json:"name"`
	Completeness float64 `json:"completeness"`
	Consistency  float64 `json:"consistency"`
	Uniqueness   float64 `json:"uniqueness"`
	QualityScore float64 `json:"quality_score"`
	DetectedType string  `json:"detected_type"`
}

type QualityReport struct {
	RowCount           int             `json:"row_count"`
	ColumnCount        int             `json:"column_count"`
	Columns            []QualityColumn `json:"columns"`
	OverallCompleteness float64        `json:"overall_completeness"`
	OverallConsistency  float64        `json:"overall_consistency"`
	OverallUniqueness   float64        `json:"overall_uniqueness"`
	OverallQualityScore float64        `json:"overall_quality_score"`
}

func runQuality(args []string) error {
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
		return fmt.Errorf("ERROR: empty CSV")
	}

	if len(records) == 0 {
		return fmt.Errorf("ERROR: empty CSV")
	}

	header := records[0]
	rows := records[1:]
	rowCount := len(rows)
	colCount := len(header)

	var columns []QualityColumn

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

		// Completeness
		completeness := 1.0
		if rowCount > 0 {
			completeness = float64(nonEmptyCount) / float64(rowCount)
		}

		// Type detection and consistency
		detectedType := "string"
		consistency := 1.0

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
				consistency = 1.0
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
					consistency = 1.0
				} else {
					detectedType = "string"
					consistency = 1.0
				}
			}
		}

		// Uniqueness
		uniqueness := 1.0
		if nonEmptyCount > 0 {
			uniqueSet := make(map[string]bool)
			for _, v := range nonEmptyValues {
				uniqueSet[v] = true
			}
			uniqueness = float64(len(uniqueSet)) / float64(nonEmptyCount)
		}

		qualityScore := (completeness + consistency + uniqueness) / 3.0

		columns = append(columns, QualityColumn{
			Name:         colName,
			Completeness: completeness,
			Consistency:  consistency,
			Uniqueness:   uniqueness,
			QualityScore: qualityScore,
			DetectedType: detectedType,
		})
	}

	// Overall scores
	sumCompleteness := 0.0
	sumConsistency := 0.0
	sumUniqueness := 0.0
	sumQuality := 0.0

	for _, col := range columns {
		sumCompleteness += col.Completeness
		sumConsistency += col.Consistency
		sumUniqueness += col.Uniqueness
		sumQuality += col.QualityScore
	}

	n := float64(colCount)
	overallCompleteness := 0.0
	overallConsistency := 0.0
	overallUniqueness := 0.0
	overallQualityScore := 0.0
	if n > 0 {
		overallCompleteness = sumCompleteness / n
		overallConsistency = sumConsistency / n
		overallUniqueness = sumUniqueness / n
		overallQualityScore = sumQuality / n
	}

	report := QualityReport{
		RowCount:            rowCount,
		ColumnCount:         colCount,
		Columns:             columns,
		OverallCompleteness: overallCompleteness,
		OverallConsistency:  overallConsistency,
		OverallUniqueness:   overallUniqueness,
		OverallQualityScore: overallQualityScore,
	}

	data, _ := json.MarshalIndent(report, "", "  ")
	return os.WriteFile(outputPath, append(data, '\n'), 0644)
}
GOEOF

# Step 4: Rebuild
go build -o dpipe ./...
