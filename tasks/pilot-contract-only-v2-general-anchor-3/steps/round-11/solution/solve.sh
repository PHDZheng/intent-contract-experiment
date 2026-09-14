#!/usr/bin/env bash
set -e

cd /app

# Step 1: Patch main.go - add fingerprint command, coalesce transform, fingerprint pipeline step
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

# Patch 1: Add "fingerprint" command case before "reconcile"
code = code.replace(
    '\tcase "reconcile":\n\t\terr = runReconcile(args)',
    '\tcase "fingerprint":\n\t\terr = runFingerprint(args)\n\tcase "reconcile":\n\t\terr = runReconcile(args)'
)

# Patch 2: Add "coalesce" transform case before "fill"
code = code.replace(
    '\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)',
    '\t\tcase "coalesce":\n\t\t\theader, rows, opErr = applyCoalesce(header, rows, op)\n\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)'
)

# Patch 3: Add "fingerprint" pipeline step before "schema"
code = code.replace(
    '\t\tcase "schema":\n\t\t\tstepErr = runSchema([]string{"--input", step.Input, "--output", step.Output})',
    '\t\tcase "fingerprint":\n\t\t\tstepErr = runFingerprint([]string{"--input", step.Input, "--output", step.Output})\n\t\tcase "schema":\n\t\t\tstepErr = runSchema([]string{"--input", step.Input, "--output", step.Output})'
)

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 2: Patch lineage.go - add fingerprint step support
python3 << 'PYEOF'
with open('lineage.go', 'r') as f:
    code = f.read()

code = code.replace(
    '\t\tcase "schema":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")',
    '\t\tcase "fingerprint":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")\n\t\tcase "schema":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")'
)

with open('lineage.go', 'w') as f:
    f.write(code)
PYEOF

# Step 3: Create fingerprint.go
cat > fingerprint.go << 'GOEOF'
package main

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"os"
	"sort"

	"golang.org/x/crypto/blake2b"
)

func runFingerprint(args []string) error {
	p := parseArgs(args)
	inputPath := p["input"]
	outputPath := p["output"]

	if _, err := os.Stat(inputPath); os.IsNotExist(err) {
		return fmt.Errorf("ERROR: file not found: %s", inputPath)
	}

	rawBytes, err := os.ReadFile(inputPath)
	if err != nil {
		return fmt.Errorf("ERROR: file not found: %s", inputPath)
	}

	fileHasher, _ := blake2b.New256(nil)
	fileHasher.Write(rawBytes)
	fileHash := fmt.Sprintf("%x", fileHasher.Sum(nil))

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

	sortedCols := make([]string, len(header))
	copy(sortedCols, header)
	sort.Strings(sortedCols)

	var dataLines []string
	for _, row := range rows {
		line := ""
		for i, val := range row {
			if i > 0 {
				line += ","
			}
			line += val
		}
		dataLines = append(dataLines, line)
	}
	sort.Strings(dataLines)

	headerLine := ""
	for i, col := range header {
		if i > 0 {
			headerLine += ","
		}
		headerLine += col
	}

	normalized := headerLine + "\n"
	for _, dl := range dataLines {
		normalized += dl + "\n"
	}

	contentHasher, _ := blake2b.New256(nil)
	contentHasher.Write([]byte(normalized))
	contentHash := fmt.Sprintf("%x", contentHasher.Sum(nil))

	result := map[string]interface{}{
		"file_hash":    fileHash,
		"row_count":    len(rows),
		"column_count": len(header),
		"columns":      sortedCols,
		"content_hash": contentHash,
	}

	data, _ := json.MarshalIndent(result, "", "  ")
	return os.WriteFile(outputPath, append(data, '\n'), 0644)
}
GOEOF

# Step 4: Create transforms9.go (coalesce transform)
cat > transforms9.go << 'GOEOF'
package main

import (
	"fmt"
)

func applyCoalesce(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	colIndices := make([]int, len(op.Columns))
	for i, colName := range op.Columns {
		idx := colIndex(header, colName)
		if idx < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", colName)
		}
		colIndices[i] = idx
	}

	newHeader := make([]string, len(header))
	copy(newHeader, header)
	newHeader = append(newHeader, op.As)

	var newRows [][]string
	for _, row := range rows {
		newRow := make([]string, len(row))
		copy(newRow, row)

		result := ""
		for _, idx := range colIndices {
			val := ""
			if idx < len(row) {
				val = row[idx]
			}
			if val != "" {
				result = val
				break
			}
		}

		newRow = append(newRow, result)
		newRows = append(newRows, newRow)
	}

	return newHeader, newRows, nil
}
GOEOF

# Step 5: Rebuild
go build -o dpipe ./...
