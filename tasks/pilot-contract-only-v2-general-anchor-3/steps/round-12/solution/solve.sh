#!/usr/bin/env bash
set -e

cd /app

# Step 1: Patch main.go - add "round" transform case before "fill"
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

code = code.replace(
    '\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)',
    '\t\tcase "round":\n\t\t\theader, rows, opErr = applyRound(header, rows, op)\n\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)'
)

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 2: Patch transforms2.go - fix normalize to default to minmax when method is unspecified
python3 << 'PYEOF'
with open('transforms2.go', 'r') as f:
    code = f.read()

# Add a default case to the normalize method switch that behaves like minmax.
# The existing switch has:
#   case "zscore": ...
#   case "minmax": ...
#   }
# We add a default case after minmax.
code = code.replace(
    '\t\t\t\tcase "minmax":\n\t\t\t\t\tif maxV == minV {\n\t\t\t\t\t\tval = "0"\n\t\t\t\t\t} else {\n\t\t\t\t\t\tval = formatFloat((v - minV) / (maxV - minV))\n\t\t\t\t\t}\n\t\t\t\t}',
    '\t\t\t\tcase "minmax":\n\t\t\t\t\tif maxV == minV {\n\t\t\t\t\t\tval = "0"\n\t\t\t\t\t} else {\n\t\t\t\t\t\tval = formatFloat((v - minV) / (maxV - minV))\n\t\t\t\t\t}\n\t\t\t\tdefault:\n\t\t\t\t\tif maxV == minV {\n\t\t\t\t\t\tval = "0"\n\t\t\t\t\t} else {\n\t\t\t\t\t\tval = formatFloat((v - minV) / (maxV - minV))\n\t\t\t\t\t}\n\t\t\t\t}'
)

with open('transforms2.go', 'w') as f:
    f.write(code)
PYEOF

# Step 3: Create transforms10.go with applyRound function
cat > transforms10.go << 'GOEOF'
package main

import (
	"fmt"
	"math"
	"strconv"
)

func applyRound(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	srcIdx := colIndex(header, op.Column)
	if srcIdx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
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
				factor := math.Pow(10, float64(op.N))
				rounded := math.Round(v*factor) / factor
				val = strconv.FormatFloat(rounded, 'f', op.N, 64)
			}
		}
		newRow[len(header)] = val
		result = append(result, newRow)
	}
	return newHeader, result, nil
}
GOEOF

# Step 4: Build
go build -o dpipe ./...
