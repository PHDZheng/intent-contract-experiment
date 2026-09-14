#!/usr/bin/env bash
set -e

cd /app

# Step 1: Patch main.go - add audit support and impute transform
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

# Patch 1: Add "impute" transform case (before "crossjoin")
code = code.replace(
    '\t\tcase "crossjoin":\n\t\t\theader, rows, opErr = applyCrossjoin(header, rows, op)',
    '\t\tcase "impute":\n\t\t\theader, rows, opErr = applyImpute(header, rows, op)\n\t\tcase "crossjoin":\n\t\t\theader, rows, opErr = applyCrossjoin(header, rows, op)'
)

# Patch 2: Add audit support to main()
# Replace the entire main function to wrap command execution with audit logging
old_main = '''func main() {
\tif len(os.Args) < 2 {
\t\tfmt.Fprintln(os.Stderr, "ERROR: no command specified")
\t\tos.Exit(1)
\t}
\tcmd := os.Args[1]
\targs := os.Args[2:]
\tvar err error
\tswitch cmd {
\tcase "ingest":
\t\terr = runIngest(args)
\tcase "transform":
\t\terr = runTransform(args)
\tcase "verify":
\t\terr = runVerify(args)
\tcase "manifest":
\t\terr = runManifest(args)
\tcase "profile":
\t\terr = runProfile(args)
\tcase "compare":
\t\terr = runCompare(args)
\tcase "validate":
\t\terr = runValidate(args)
\tcase "lineage":
\t\terr = runLineage(args)
\tcase "drift":
\t\terr = runDrift(args)
\tcase "pipeline":
\t\terr = runPipeline(args)
\tdefault:
\t\tfmt.Fprintf(os.Stderr, "ERROR: unknown command: %s\\n", cmd)
\t\tos.Exit(1)
\t}
\tif err != nil {
\t\tfmt.Fprintln(os.Stderr, err)
\t\tos.Exit(1)
\t}
}'''

new_main = '''func main() {
\tif len(os.Args) < 2 {
\t\tfmt.Fprintln(os.Stderr, "ERROR: no command specified")
\t\tos.Exit(1)
\t}
\tcmd := os.Args[1]
\targs := os.Args[2:]

\t// Extract --audit flag
\tvar auditPath string
\tvar filteredArgs []string
\tfor i := 0; i < len(args); i++ {
\t\tif args[i] == "--audit" && i+1 < len(args) {
\t\t\tauditPath = args[i+1]
\t\t\ti++
\t\t} else {
\t\t\tfilteredArgs = append(filteredArgs, args[i])
\t\t}
\t}
\targs = filteredArgs

\tstartTime := time.Now()
\tvar err error
\tswitch cmd {
\tcase "ingest":
\t\terr = runIngest(args)
\tcase "transform":
\t\terr = runTransform(args)
\tcase "verify":
\t\terr = runVerify(args)
\tcase "manifest":
\t\terr = runManifest(args)
\tcase "profile":
\t\terr = runProfile(args)
\tcase "compare":
\t\terr = runCompare(args)
\tcase "validate":
\t\terr = runValidate(args)
\tcase "lineage":
\t\terr = runLineage(args)
\tcase "drift":
\t\terr = runDrift(args)
\tcase "pipeline":
\t\terr = runPipeline(args)
\tdefault:
\t\tfmt.Fprintf(os.Stderr, "ERROR: unknown command: %s\\n", cmd)
\t\tos.Exit(1)
\t}
\tduration := time.Since(startTime)

\tif auditPath != "" {
\t\twriteAuditEntry(auditPath, cmd, args, startTime, duration, err)
\t}

\tif err != nil {
\t\tfmt.Fprintln(os.Stderr, err)
\t\tos.Exit(1)
\t}
}'''

code = code.replace(old_main, new_main)

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 2: Create audit.go
cat > audit.go << 'GOEOF'
package main

import (
	"encoding/json"
	"os"
	"time"
)

type AuditEntry struct {
	Command    string      `json:"command"`
	Args       []string    `json:"args"`
	Timestamp  string      `json:"timestamp"`
	DurationMs int64       `json:"duration_ms"`
	Success    bool        `json:"success"`
	Error      interface{} `json:"error"`
	InputSize  interface{} `json:"input_size"`
	OutputSize interface{} `json:"output_size"`
}

func getInputPath(cmd string, args []string) string {
	p := parseArgs(args)
	switch cmd {
	case "ingest":
		return p["input"]
	case "transform":
		return p["input"]
	case "profile":
		return p["input"]
	case "validate":
		return p["input"]
	case "verify":
		return p["file"]
	case "compare":
		return p["left"]
	case "drift":
		return p["baseline"]
	case "pipeline":
		return p["config"]
	case "lineage":
		return p["config"]
	}
	return ""
}

func getOutputPath(cmd string, args []string) string {
	if cmd == "verify" || cmd == "pipeline" {
		return ""
	}
	p := parseArgs(args)
	return p["output"]
}

func writeAuditEntry(auditPath string, cmd string, args []string, startTime time.Time, duration time.Duration, cmdErr error) {
	entry := AuditEntry{
		Command:    cmd,
		Args:       args,
		Timestamp:  startTime.UTC().Format("2006-01-02T15:04:05Z"),
		DurationMs: duration.Milliseconds(),
		Success:    cmdErr == nil,
	}

	if entry.Args == nil {
		entry.Args = []string{}
	}

	if cmdErr != nil {
		entry.Error = cmdErr.Error()
	}

	inputPath := getInputPath(cmd, args)
	if inputPath != "" {
		if info, err := os.Stat(inputPath); err == nil {
			entry.InputSize = info.Size()
		}
	}

	if cmdErr == nil {
		outputPath := getOutputPath(cmd, args)
		if outputPath != "" {
			if info, err := os.Stat(outputPath); err == nil {
				entry.OutputSize = info.Size()
			}
		}
	}

	var entries []AuditEntry
	if data, err := os.ReadFile(auditPath); err == nil {
		if json.Unmarshal(data, &entries) != nil {
			entries = nil
		}
	}

	entries = append(entries, entry)

	data, _ := json.MarshalIndent(entries, "", "  ")
	os.WriteFile(auditPath, append(data, '\n'), 0644)
}
GOEOF

# Step 3: Create transforms6.go (impute)
cat > transforms6.go << 'GOEOF'
package main

import (
	"fmt"
	"math"
	"sort"
	"strconv"
)

func applyImpute(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	srcIdx := colIndex(header, op.Column)
	if srcIdx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}

	// Collect non-empty numeric values
	var numVals []float64
	for _, row := range rows {
		if srcIdx < len(row) && row[srcIdx] != "" {
			v, err := strconv.ParseFloat(row[srcIdx], 64)
			if err == nil {
				numVals = append(numVals, v)
			}
		}
	}

	if len(numVals) == 0 {
		return header, rows, nil
	}

	var fillValue float64

	switch op.Method {
	case "mean":
		sum := 0.0
		for _, v := range numVals {
			sum += v
		}
		fillValue = sum / float64(len(numVals))

	case "median":
		sorted := make([]float64, len(numVals))
		copy(sorted, numVals)
		sort.Float64s(sorted)
		fillValue = calcPercentile(sorted, 50)

	case "mode":
		freqMap := make(map[float64]int)
		for _, v := range numVals {
			freqMap[v]++
		}
		maxFreq := 0
		for _, cnt := range freqMap {
			if cnt > maxFreq {
				maxFreq = cnt
			}
		}
		fillValue = math.Inf(1)
		for v, cnt := range freqMap {
			if cnt == maxFreq && v < fillValue {
				fillValue = v
			}
		}
	}

	fillStr := formatFloat(fillValue)

	// Make a copy of rows and fill empty cells
	newRows := make([][]string, len(rows))
	for i, row := range rows {
		newRow := make([]string, len(row))
		copy(newRow, row)
		if srcIdx < len(newRow) && newRow[srcIdx] == "" {
			newRow[srcIdx] = fillStr
		}
		newRows[i] = newRow
	}

	return header, newRows, nil
}
GOEOF

# Step 4: Rebuild
go build -o dpipe ./...
