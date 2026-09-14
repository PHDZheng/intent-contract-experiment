#!/usr/bin/env bash
set -e

cd /app

# Step 1: Patch main.go - manifest format change + reconcile command + pipeline step
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

# Patch 1: Change ManifestEntry struct field from BLAKE2b to Checksum + Algorithm
code = code.replace(
    '\t\tBLAKE2b   string `json:"blake2b"`',
    '\t\tChecksum  string `json:"checksum"`\n\t\tAlgorithm string `json:"algorithm"`'
)

# Patch 2: Update manifest entry assignment to use new field names
code = code.replace(
    '\t\t\tBLAKE2b:   fmt.Sprintf("%x", h),',
    '\t\t\tChecksum:  fmt.Sprintf("%x", h),\n\t\t\tAlgorithm: "blake2b-256",'
)

# Patch 3: Fix any remaining .BLAKE2b references (e.g. in verify or elsewhere)
code = code.replace('.BLAKE2b', '.Checksum')

# Patch 4: Add "reconcile" command case before "schema"
code = code.replace(
    '\tcase "schema":\n\t\terr = runSchema(args)',
    '\tcase "reconcile":\n\t\terr = runReconcile(args)\n\tcase "schema":\n\t\terr = runSchema(args)'
)

# Patch 5: Add "reconcile" pipeline step before "schema"
code = code.replace(
    '\t\tcase "schema":\n\t\t\tstepErr = runSchema([]string{"--input", step.Input, "--output", step.Output})',
    '\t\tcase "reconcile":\n\t\t\tstepErr = runReconcile([]string{"--left", step.Left, "--right", step.Right, "--output", step.Output})\n\t\tcase "schema":\n\t\t\tstepErr = runSchema([]string{"--input", step.Input, "--output", step.Output})'
)

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 2: Patch lineage.go - add reconcile step support
python3 << 'PYEOF'
with open('lineage.go', 'r') as f:
    code = f.read()

# Add reconcile case before schema case in lineage
code = code.replace(
    '\t\tcase "schema":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")',
    '\t\tcase "reconcile":\n\t\t\tinputs = []string{getStr(step, "left"), getStr(step, "right")}\n\t\t\toutput = getStr(step, "output")\n\t\tcase "schema":\n\t\t\tinputs = []string{getStr(step, "input")}\n\t\t\toutput = getStr(step, "output")'
)

with open('lineage.go', 'w') as f:
    f.write(code)
PYEOF

# Step 3: Create reconcile.go
cat > reconcile.go << 'GOEOF'
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
)

type ReconcileManifest struct {
	Files []ReconcileEntry `json:"files"`
}

type ReconcileEntry struct {
	Path     string `json:"path"`
	Checksum string `json:"checksum"`
}

type ReconcileReport struct {
	Added     []string         `json:"added"`
	Removed   []string         `json:"removed"`
	Modified  []string         `json:"modified"`
	Unchanged []string         `json:"unchanged"`
	Summary   ReconcileSummary `json:"summary"`
}

type ReconcileSummary struct {
	TotalLeft int `json:"total_left"`
	TotalRight int `json:"total_right"`
	Added     int `json:"added"`
	Removed   int `json:"removed"`
	Modified  int `json:"modified"`
	Unchanged int `json:"unchanged"`
}

func runReconcile(args []string) error {
	p := parseArgs(args)
	leftPath := p["left"]
	rightPath := p["right"]
	outputPath := p["output"]

	leftManifest, err := readReconcileManifest(leftPath)
	if err != nil {
		return err
	}

	rightManifest, err := readReconcileManifest(rightPath)
	if err != nil {
		return err
	}

	leftMap := make(map[string]string)
	for _, e := range leftManifest.Files {
		leftMap[e.Path] = e.Checksum
	}

	rightMap := make(map[string]string)
	for _, e := range rightManifest.Files {
		rightMap[e.Path] = e.Checksum
	}

	var added, removed, modified, unchanged []string

	for path := range rightMap {
		if _, ok := leftMap[path]; !ok {
			added = append(added, path)
		}
	}

	for path := range leftMap {
		if _, ok := rightMap[path]; !ok {
			removed = append(removed, path)
		}
	}

	for path, leftCS := range leftMap {
		if rightCS, ok := rightMap[path]; ok {
			if leftCS != rightCS {
				modified = append(modified, path)
			} else {
				unchanged = append(unchanged, path)
			}
		}
	}

	sort.Strings(added)
	sort.Strings(removed)
	sort.Strings(modified)
	sort.Strings(unchanged)

	if added == nil {
		added = []string{}
	}
	if removed == nil {
		removed = []string{}
	}
	if modified == nil {
		modified = []string{}
	}
	if unchanged == nil {
		unchanged = []string{}
	}

	report := ReconcileReport{
		Added:     added,
		Removed:   removed,
		Modified:  modified,
		Unchanged: unchanged,
		Summary: ReconcileSummary{
			TotalLeft:  len(leftManifest.Files),
			TotalRight: len(rightManifest.Files),
			Added:      len(added),
			Removed:    len(removed),
			Modified:   len(modified),
			Unchanged:  len(unchanged),
		},
	}

	data, _ := json.MarshalIndent(report, "", "  ")
	return os.WriteFile(outputPath, append(data, '\n'), 0644)
}

func readReconcileManifest(path string) (*ReconcileManifest, error) {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return nil, fmt.Errorf("ERROR: file not found: %s", path)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("ERROR: file not found: %s", path)
	}

	var m ReconcileManifest
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, fmt.Errorf("ERROR: invalid manifest: %s", path)
	}

	return &m, nil
}
GOEOF

# Step 4: Rebuild
go build -o dpipe ./...
