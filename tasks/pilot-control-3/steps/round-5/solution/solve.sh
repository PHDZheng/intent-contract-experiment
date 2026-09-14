#!/usr/bin/env bash
set -e

cd /app

# Step 1: Add blake2b dependency
go get golang.org/x/crypto/blake2b

# Step 2: Patch main.go for BLAKE2b changes and new lineage command
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

# Patch 1: Replace crypto/sha256 import with blake2b (sha256 is no longer used)
code = code.replace(
    '"crypto/sha256"',
    '"golang.org/x/crypto/blake2b"'
)

# Patch 2: Remove writeSHA256 calls AND the writeSHA256 function definition
import re
# Remove all call sites: lines like \twriteSHA256(outputPath)
lines = code.split('\n')
lines = [l for l in lines if l.strip() != 'writeSHA256(outputPath)']
code = '\n'.join(lines)
# Ensure stale sidecars from previous rounds/runs are removed after successful writes
code = code.replace(
    '\twriteCSV(outputPath, header, validRows)\n\n\tif len(rejectedRows) > 0 {',
    '\twriteCSV(outputPath, header, validRows)\n\t_ = os.Remove(outputPath + ".sha256")\n\n\tif len(rejectedRows) > 0 {'
)
code = code.replace(
    '\twriteCSV(outputPath, header, rows)\n\treturn nil',
    '\twriteCSV(outputPath, header, rows)\n\t_ = os.Remove(outputPath + ".sha256")\n\treturn nil'
)
# Remove the entire writeSHA256 function definition
code = re.sub(r'\nfunc writeSHA256\(.*?\n\}\n', '\n', code, count=1, flags=re.DOTALL)

# Patch 4: Change manifest command to use BLAKE2b instead of SHA256
code = code.replace(
    '\t\tSHA256    string `json:"sha256"`',
    '\t\tBLAKE2b   string `json:"blake2b"`'
)
code = code.replace(
    '\t\th := sha256.Sum256(data)\n',
    '\t\th := blake2b.Sum256(data)\n'
)
code = code.replace(
    '\t\t\tSHA256:    fmt.Sprintf("%x", h),',
    '\t\t\tBLAKE2b:   fmt.Sprintf("%x", h),'
)

# Patch 5: Change verify command to use BLAKE2b instead of SHA256
code = code.replace(
    '\tactual := fmt.Sprintf("%x", sha256.Sum256(data))',
    '\tactual := fmt.Sprintf("%x", blake2b.Sum256(data))'
)

# Patch 6: Add "lineage" command case (before "drift")
code = code.replace(
    '\tcase "drift":\n\t\terr = runDrift(args)',
    '\tcase "lineage":\n\t\terr = runLineage(args)\n\tcase "drift":\n\t\terr = runDrift(args)'
)

# Patch 7: Add "lineage" pipeline step (before "drift" pipeline step)
code = code.replace(
    '\t\tcase "drift":',
    '\t\tcase "lineage":\n\t\t\tstepErr = runLineage([]string{"--config", step.Config, "--output", step.Output})\n\t\tcase "drift":'
)

# Patch 8: Add Config field to PipelineStep struct if not present
pstruct = code.split('type PipelineStep struct')[1].split('}')[0] if 'type PipelineStep struct' in code else ''
if '"config,omitempty"' not in pstruct:
    code = code.replace(
        '\tSchema   string `json:"schema,omitempty"`',
        '\tSchema   string `json:"schema,omitempty"`\n\tConfig   string `json:"config,omitempty"`'
    )

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 3: Create lineage.go
cat > lineage.go << 'GOEOF'
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
)

type LineageNode struct {
	ID         string      `json:"id"`
	Type       string      `json:"type"`
	ProducedBy interface{} `json:"produced_by"`
}

type LineageEdge struct {
	From string `json:"from"`
	To   string `json:"to"`
	Step int    `json:"step"`
}

type LineageStep struct {
	Index  int         `json:"index"`
	Type   string      `json:"type"`
	Inputs []string    `json:"inputs"`
	Output interface{} `json:"output"`
}

type LineageReport struct {
	Nodes []LineageNode `json:"nodes"`
	Edges []LineageEdge `json:"edges"`
	Steps []LineageStep `json:"steps"`
}

type rawPipelineConfig struct {
	Seed  interface{}              `json:"seed"`
	Steps []map[string]interface{} `json:"steps"`
}

func getStr(m map[string]interface{}, key string) string {
	if v, ok := m[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

func runLineage(args []string) error {
	p := parseArgs(args)
	configPath := p["config"]
	outputPath := p["output"]

	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		return fmt.Errorf("ERROR: file not found: %s", configPath)
	}

	configData, err := os.ReadFile(configPath)
	if err != nil {
		return fmt.Errorf("ERROR: file not found: %s", configPath)
	}

	var config rawPipelineConfig
	if err := json.Unmarshal(configData, &config); err != nil {
		return fmt.Errorf("ERROR: invalid pipeline config: %s", configPath)
	}

	producedBy := make(map[string]int)
	allFiles := make(map[string]bool)

	var edges []LineageEdge
	var steps []LineageStep

	for i, step := range config.Steps {
		stepIdx := i + 1
		stepType := getStr(step, "type")
		var inputs []string
		var output string
		hasOutput := true

		switch stepType {
		case "ingest":
			inputs = []string{getStr(step, "file")}
			output = getStr(step, "output")
		case "transform":
			inputs = []string{getStr(step, "input"), getStr(step, "recipe")}
			output = getStr(step, "output")
		case "profile":
			inputs = []string{getStr(step, "input")}
			output = getStr(step, "output")
		case "compare":
			inputs = []string{getStr(step, "left"), getStr(step, "right")}
			output = getStr(step, "output")
		case "manifest":
			inputs = []string{getStr(step, "dir")}
			output = getStr(step, "output")
		case "verify":
			inputs = []string{getStr(step, "file"), getStr(step, "checksum")}
			hasOutput = false
		case "validate":
			inputs = []string{getStr(step, "input"), getStr(step, "schema")}
			output = getStr(step, "output")
		case "drift":
			inputs = []string{getStr(step, "baseline"), getStr(step, "current")}
			output = getStr(step, "output")
		default:
			inputs = []string{}
			hasOutput = false
		}

		var filteredInputs []string
		for _, inp := range inputs {
			if inp != "" {
				filteredInputs = append(filteredInputs, inp)
				allFiles[inp] = true
			}
		}
		inputs = filteredInputs

		if hasOutput && output != "" {
			producedBy[output] = stepIdx
			allFiles[output] = true

			for _, inp := range inputs {
				edges = append(edges, LineageEdge{
					From: inp,
					To:   output,
					Step: stepIdx,
				})
			}
		}

		ls := LineageStep{
			Index:  stepIdx,
			Type:   stepType,
			Inputs: inputs,
		}
		if hasOutput && output != "" {
			ls.Output = output
		}
		if ls.Inputs == nil {
			ls.Inputs = []string{}
		}

		steps = append(steps, ls)
	}

	var nodes []LineageNode
	for file := range allFiles {
		node := LineageNode{
			ID:   file,
			Type: "file",
		}
		if stepIdx, ok := producedBy[file]; ok {
			node.ProducedBy = stepIdx
		}
		nodes = append(nodes, node)
	}

	sort.Slice(nodes, func(i, j int) bool {
		return nodes[i].ID < nodes[j].ID
	})

	sort.Slice(edges, func(i, j int) bool {
		if edges[i].Step != edges[j].Step {
			return edges[i].Step < edges[j].Step
		}
		return edges[i].From < edges[j].From
	})

	sort.Slice(steps, func(i, j int) bool {
		return steps[i].Index < steps[j].Index
	})

	if nodes == nil {
		nodes = []LineageNode{}
	}
	if edges == nil {
		edges = []LineageEdge{}
	}
	if steps == nil {
		steps = []LineageStep{}
	}

	report := LineageReport{
		Nodes: nodes,
		Edges: edges,
		Steps: steps,
	}

	data, _ := json.MarshalIndent(report, "", "  ")
	return os.WriteFile(outputPath, append(data, '\n'), 0644)
}
GOEOF

# Step 4: Rebuild
go build -o dpipe ./...
