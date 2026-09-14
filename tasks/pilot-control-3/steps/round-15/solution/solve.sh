#!/usr/bin/env bash
set -e

cd /app

# Step 1: Patch snapshot.go - change MD5 to SHA-256
python3 << 'PYEOF'
with open('snapshot.go', 'r') as f:
    code = f.read()

# Replace crypto/md5 import with crypto/sha256
code = code.replace('"crypto/md5"', '"crypto/sha256"')

# Replace md5.Sum with sha256.Sum256
code = code.replace('hash := md5.Sum([]byte(combined))', 'hash := sha256.Sum256([]byte(combined))')

with open('snapshot.go', 'w') as f:
    f.write(code)
PYEOF

# Step 2: Patch main.go - add tag transform case before fill
python3 << 'PYEOF'
with open('main.go', 'r') as f:
    code = f.read()

code = code.replace(
    '\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)',
    '\t\tcase "tag":\n\t\t\theader, rows, opErr = applyTag(header, rows, op)\n\t\tcase "fill":\n\t\t\theader, rows, opErr = applyFill(header, rows, op)'
)

with open('main.go', 'w') as f:
    f.write(code)
PYEOF

# Step 3: Create transforms13.go for applyTag
cat > transforms13.go << 'GOEOF'
package main

import (
	"fmt"
)

func applyTag(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	if op.As == "" {
		return header, rows, fmt.Errorf("ERROR: invalid recipe: missing 'as' field")
	}

	newHeader := make([]string, len(header))
	copy(newHeader, header)
	newHeader = append(newHeader, op.As)

	var newRows [][]string
	for _, row := range rows {
		newRow := make([]string, len(row))
		copy(newRow, row)
		newRow = append(newRow, op.Value)
		newRows = append(newRows, newRow)
	}

	return newHeader, newRows, nil
}
GOEOF

# Step 4: Build
go build -o dpipe ./...
