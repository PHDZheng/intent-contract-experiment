#!/usr/bin/env bash
set -e

cd /app

# Initialize Go module
go mod init dpipe

# Create main.go
cat > main.go << 'GOEOF'
package main

import (
	"crypto/sha256"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"math"
	"math/rand"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "ERROR: no command specified")
		os.Exit(1)
	}
	cmd := os.Args[1]
	args := os.Args[2:]
	var err error
	switch cmd {
	case "ingest":
		err = runIngest(args)
	case "transform":
		err = runTransform(args)
	case "verify":
		err = runVerify(args)
	case "manifest":
		err = runManifest(args)
	case "pipeline":
		err = runPipeline(args)
	default:
		fmt.Fprintf(os.Stderr, "ERROR: unknown command: %s\n", cmd)
		os.Exit(1)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func parseArgs(args []string) map[string]string {
	m := make(map[string]string)
	for i := 0; i < len(args)-1; i += 2 {
		key := strings.TrimPrefix(args[i], "--")
		m[key] = args[i+1]
	}
	return m
}

type ColumnSchema struct {
	Name     string   `json:"name"`
	Type     string   `json:"type"`
	Required bool     `json:"required"`
	Unique   bool     `json:"unique"`
	Min      *float64 `json:"min"`
	Max      *float64 `json:"max"`
	Pattern  string   `json:"pattern"`
}

type Schema struct {
	Columns    []ColumnSchema `json:"columns"`
	PrimaryKey []string       `json:"primary_key"`
}

func loadSchema(path string) (*Schema, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var s Schema
	if err := json.Unmarshal(data, &s); err != nil {
		return nil, fmt.Errorf("ERROR: malformed JSON: %s", path)
	}
	for _, col := range s.Columns {
		if col.Pattern != "" {
			if _, err := regexp.Compile(col.Pattern); err != nil {
				return nil, fmt.Errorf("ERROR: invalid pattern: %s", col.Pattern)
			}
		}
	}
	return &s, nil
}

func validateValue(val string, typ string) (interface{}, error) {
	switch typ {
	case "int":
		return strconv.ParseInt(val, 10, 64)
	case "float":
		return strconv.ParseFloat(val, 64)
	case "string":
		return val, nil
	case "datetime":
		t, err := time.Parse(time.RFC3339, val)
		if err != nil {
			return nil, err
		}
		return t, nil
	default:
		return nil, fmt.Errorf("unknown type: %s", typ)
	}
}

func runIngest(args []string) error {
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

	schema, err := loadSchema(schemaPath)
	if err != nil {
		return err
	}

	f, err := os.Open(inputPath)
	if err != nil {
		return fmt.Errorf("ERROR: file not found: %s", inputPath)
	}
	defer f.Close()

	reader := csv.NewReader(f)
	allRecords, err := reader.ReadAll()
	if err != nil {
		return fmt.Errorf("ERROR: cannot parse CSV: %s", inputPath)
	}

	if len(allRecords) == 0 {
		return fmt.Errorf("ERROR: empty CSV: %s", inputPath)
	}

	header := allRecords[0]
	colIdx := make(map[string]int)
	for i, h := range header {
		colIdx[h] = i
	}

	var validRows [][]string
	var rejectedRows [][]string

	for _, row := range allRecords[1:] {
		reason := ""
		valid := true

		// Phase 1: required/type checks
		for _, col := range schema.Columns {
			idx, exists := colIdx[col.Name]
			if !exists {
				if col.Required {
					reason = fmt.Sprintf("missing required column: %s", col.Name)
					valid = false
					break
				}
				continue
			}
			if idx >= len(row) {
				if col.Required {
					reason = fmt.Sprintf("missing value for required column: %s", col.Name)
					valid = false
					break
				}
				continue
			}
			val := row[idx]
			if val == "" {
				if col.Required {
					reason = fmt.Sprintf("empty value for required column: %s", col.Name)
					valid = false
					break
				}
				continue
			}
			if _, err := validateValue(val, col.Type); err != nil {
				reason = fmt.Sprintf("invalid %s value for column %s: %s", col.Type, col.Name, val)
				valid = false
				break
			}
		}

		if !valid {
			rejected := make([]string, len(row))
			copy(rejected, row)
			rejected = append(rejected, reason)
			rejectedRows = append(rejectedRows, rejected)
			continue
		}

		// Phase 2: range checks
		for _, col := range schema.Columns {
			if col.Min == nil && col.Max == nil {
				continue
			}
			idx, exists := colIdx[col.Name]
			if !exists || idx >= len(row) {
				continue
			}
			val := row[idx]
			if val == "" {
				continue
			}
			var numVal float64
			switch col.Type {
			case "int":
				iv, _ := strconv.ParseInt(val, 10, 64)
				numVal = float64(iv)
			case "float":
				numVal, _ = strconv.ParseFloat(val, 64)
			default:
				continue
			}
			if col.Min != nil && numVal < *col.Min {
				reason = fmt.Sprintf("value out of range for column %s: %s", col.Name, val)
				valid = false
				break
			}
			if col.Max != nil && numVal > *col.Max {
				reason = fmt.Sprintf("value out of range for column %s: %s", col.Name, val)
				valid = false
				break
			}
		}

		if !valid {
			rejected := make([]string, len(row))
			copy(rejected, row)
			rejected = append(rejected, reason)
			rejectedRows = append(rejectedRows, rejected)
			continue
		}

		// Phase 3: pattern checks
		for _, col := range schema.Columns {
			if col.Pattern == "" {
				continue
			}
			idx, exists := colIdx[col.Name]
			if !exists || idx >= len(row) {
				continue
			}
			val := row[idx]
			if val == "" {
				continue
			}
			re := regexp.MustCompile(col.Pattern)
			if !re.MatchString(val) {
				reason = fmt.Sprintf("value does not match pattern for column %s: %s", col.Name, val)
				valid = false
				break
			}
		}

		if !valid {
			rejected := make([]string, len(row))
			copy(rejected, row)
			rejected = append(rejected, reason)
			rejectedRows = append(rejectedRows, rejected)
			continue
		}

		validRows = append(validRows, row)
	}

	// Phase 4: uniqueness checks across valid rows in input file order
	uniqueCols := []ColumnSchema{}
	for _, col := range schema.Columns {
		if col.Unique {
			uniqueCols = append(uniqueCols, col)
		}
	}

	if len(uniqueCols) > 0 {
		var finalValid [][]string
		seen := make(map[string]map[string]bool)
		for _, col := range uniqueCols {
			seen[col.Name] = make(map[string]bool)
		}
		for _, row := range validRows {
			rejected := false
			var rejReason string
			for _, col := range uniqueCols {
				idx, exists := colIdx[col.Name]
				if !exists || idx >= len(row) {
					continue
				}
				val := row[idx]
				if val == "" {
					continue
				}
				if seen[col.Name][val] {
					rejReason = fmt.Sprintf("duplicate value for unique column: %s", col.Name)
					rejected = true
					break
				}
				seen[col.Name][val] = true
			}
			if rejected {
				rej := make([]string, len(row))
				copy(rej, row)
				rej = append(rej, rejReason)
				rejectedRows = append(rejectedRows, rej)
			} else {
				finalValid = append(finalValid, row)
			}
		}
		validRows = finalValid
	}

	// Sort by composite primary key
	sort.SliceStable(validRows, func(i, j int) bool {
		for _, pkCol := range schema.PrimaryKey {
			idx, exists := colIdx[pkCol]
			if !exists {
				continue
			}
			a := validRows[i][idx]
			b := validRows[j][idx]
			pkType := "string"
			for _, col := range schema.Columns {
				if col.Name == pkCol {
					pkType = col.Type
					break
				}
			}
			cmp := 0
			switch pkType {
			case "int":
				ai, _ := strconv.ParseInt(a, 10, 64)
				bi, _ := strconv.ParseInt(b, 10, 64)
				if ai < bi {
					cmp = -1
				} else if ai > bi {
					cmp = 1
				}
			case "float":
				af, _ := strconv.ParseFloat(a, 64)
				bf, _ := strconv.ParseFloat(b, 64)
				if af < bf {
					cmp = -1
				} else if af > bf {
					cmp = 1
				}
			case "datetime":
				at, _ := time.Parse(time.RFC3339, a)
				bt, _ := time.Parse(time.RFC3339, b)
				if at.Before(bt) {
					cmp = -1
				} else if at.After(bt) {
					cmp = 1
				}
			default:
				if a < b {
					cmp = -1
				} else if a > b {
					cmp = 1
				}
			}
			if cmp != 0 {
				return cmp < 0
			}
		}
		return false
	})

	writeCSV(outputPath, header, validRows)
	writeSHA256(outputPath)

	if len(rejectedRows) > 0 {
		rejHeader := append(append([]string{}, header...), "rejection_reason")
		writeCSV(outputPath+".rejected", rejHeader, rejectedRows)
	}
	return nil
}

func writeCSV(path string, header []string, rows [][]string) {
	f, err := os.Create(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: cannot create file: %s\n", path)
		os.Exit(1)
	}
	defer f.Close()
	w := csv.NewWriter(f)
	w.Write(header)
	for _, row := range rows {
		w.Write(row)
	}
	w.Flush()
}

func writeSHA256(path string) {
	data, err := os.ReadFile(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: cannot read file for checksum: %s\n", path)
		os.Exit(1)
	}
	h := sha256.Sum256(data)
	os.WriteFile(path+".sha256", []byte(fmt.Sprintf("%x\n", h)), 0644)
}

func colIndex(header []string, name string) int {
	for i, h := range header {
		if h == name {
			return i
		}
	}
	return -1
}

func formatFloat(v float64) string {
	if math.IsNaN(v) {
		return "NaN"
	}
	if math.IsInf(v, 1) {
		return "+Inf"
	}
	if math.IsInf(v, -1) {
		return "-Inf"
	}
	return strconv.FormatFloat(v, 'f', -1, 64)
}

// --- Transform types ---

type Aggregation struct {
	Column   string `json:"column"`
	Function string `json:"function"`
	As       string `json:"as"`
}

type OrderBySpec struct {
	Column string `json:"column"`
	Order  string `json:"order"`
}

type HavingClause struct {
	Column    string  `json:"column"`
	Condition string  `json:"condition"`
	Threshold float64 `json:"threshold"`
}

type TransformOp struct {
	Op           string        `json:"op"`
	Column       string        `json:"column,omitempty"`
	Condition    string        `json:"condition,omitempty"`
	Threshold    float64       `json:"threshold,omitempty"`
	Name         string        `json:"name,omitempty"`
	Expression   string        `json:"expression,omitempty"`
	Fraction     float64       `json:"fraction,omitempty"`
	Order        string        `json:"order,omitempty"`
	From         string        `json:"from,omitempty"`
	To           string        `json:"to,omitempty"`
	Columns      []string      `json:"columns,omitempty"`
	GroupBy      []string      `json:"group_by,omitempty"`
	Aggregations []Aggregation `json:"aggregations,omitempty"`
	Right        string        `json:"right,omitempty"`
	On           string        `json:"on,omitempty"`
	JoinType     string        `json:"type,omitempty"`
	// Window fields
	Function     string        `json:"function,omitempty"`
	PartitionBy  []string      `json:"partition_by,omitempty"`
	OrderBy      []OrderBySpec `json:"order_by,omitempty"`
	As           string        `json:"as,omitempty"`
	SourceColumn string        `json:"source_column,omitempty"`
	Offset       int           `json:"offset,omitempty"`
	Default      string        `json:"default,omitempty"`
	N            int           `json:"n,omitempty"`
	// Pivot/Unpivot fields
	Index        []string      `json:"index,omitempty"`
	Value        string        `json:"value,omitempty"`
	NameTo       string        `json:"name_to,omitempty"`
	ValueTo      string        `json:"value_to,omitempty"`
	// Having support for aggregate
	Having       *HavingClause `json:"having,omitempty"`
	// Fill fields
	Strategy     string        `json:"strategy,omitempty"`
}

func runTransform(args []string) error {
	p := parseArgs(args)
	inputPath := p["input"]
	recipePath := p["recipe"]
	outputPath := p["output"]
	seedStr := p["seed"]

	if _, err := os.Stat(inputPath); os.IsNotExist(err) {
		return fmt.Errorf("ERROR: file not found: %s", inputPath)
	}
	if _, err := os.Stat(recipePath); os.IsNotExist(err) {
		return fmt.Errorf("ERROR: file not found: %s", recipePath)
	}

	seed, err := strconv.ParseUint(seedStr, 10, 64)
	if err != nil {
		return fmt.Errorf("ERROR: invalid seed: %s", seedStr)
	}

	recipeData, err := os.ReadFile(recipePath)
	if err != nil {
		return fmt.Errorf("ERROR: file not found: %s", recipePath)
	}

	var ops []TransformOp
	if err := json.Unmarshal(recipeData, &ops); err != nil {
		return fmt.Errorf("ERROR: malformed JSON: %s", recipePath)
	}

	f, err := os.Open(inputPath)
	if err != nil {
		return fmt.Errorf("ERROR: file not found: %s", inputPath)
	}
	defer f.Close()

	reader := csv.NewReader(f)
	allRecords, err := reader.ReadAll()
	if err != nil {
		return fmt.Errorf("ERROR: cannot parse CSV: %s", inputPath)
	}

	if len(allRecords) == 0 {
		return fmt.Errorf("ERROR: empty CSV")
	}

	header := allRecords[0]
	rows := allRecords[1:]
	rng := rand.New(rand.NewSource(int64(seed)))

	for _, op := range ops {
		var opErr error
		switch op.Op {
		case "filter":
			header, rows, opErr = applyFilter(header, rows, op)
		case "derive":
			header, rows = applyDerive(header, rows, op)
		case "sample":
			header, rows = applySample(header, rows, op, rng)
		case "sort":
			header, rows, opErr = applySort(header, rows, op)
		case "rename":
			header, rows = applyRename(header, rows, op)
		case "drop":
			header, rows = applyDrop(header, rows, op)
		case "aggregate":
			header, rows, opErr = applyAggregate(header, rows, op)
		case "join":
			header, rows, opErr = applyJoin(header, rows, op)
		case "window":
			header, rows, opErr = applyWindow(header, rows, op)
		case "pivot":
			header, rows, opErr = applyPivot(header, rows, op)
		case "unpivot":
			header, rows, opErr = applyUnpivot(header, rows, op)
		case "fill":
			header, rows, opErr = applyFill(header, rows, op)
		default:
			return fmt.Errorf("ERROR: invalid recipe: unknown operation %s", op.Op)
		}
		if opErr != nil {
			return opErr
		}
	}

	writeCSV(outputPath, header, rows)
	writeSHA256(outputPath)
	return nil
}

// --- Transform operations ---

func applyFilter(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	idx := colIndex(header, op.Column)
	if idx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}
	var result [][]string
	for _, row := range rows {
		val, err := strconv.ParseFloat(row[idx], 64)
		if err != nil {
			continue
		}
		keep := false
		switch op.Condition {
		case "gt":
			keep = val > op.Threshold
		case "gte":
			keep = val >= op.Threshold
		case "lt":
			keep = val < op.Threshold
		case "lte":
			keep = val <= op.Threshold
		case "eq":
			keep = val == op.Threshold
		case "neq":
			keep = val != op.Threshold
		}
		if keep {
			result = append(result, row)
		}
	}
	return header, result, nil
}

func applyDerive(header []string, rows [][]string, op TransformOp) ([]string, [][]string) {
	newHeader := append(append([]string{}, header...), op.Name)
	var result [][]string
	for _, row := range rows {
		val := evalExpr(op.Expression, header, row)
		valStr := formatFloat(val)
		newRow := append(append([]string{}, row...), valStr)
		result = append(result, newRow)
	}
	return newHeader, result
}

func applySample(header []string, rows [][]string, op TransformOp, rng *rand.Rand) ([]string, [][]string) {
	var result [][]string
	for _, row := range rows {
		if rng.Float64() < op.Fraction {
			result = append(result, row)
		}
	}
	return header, result
}

func applySort(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	idx := colIndex(header, op.Column)
	if idx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}
	sort.SliceStable(rows, func(i, j int) bool {
		a := rows[i][idx]
		b := rows[j][idx]
		af, aerr := strconv.ParseFloat(a, 64)
		bf, berr := strconv.ParseFloat(b, 64)
		if aerr == nil && berr == nil {
			if op.Order == "desc" {
				return af > bf
			}
			return af < bf
		}
		if op.Order == "desc" {
			return a > b
		}
		return a < b
	})
	return header, rows, nil
}

func applyRename(header []string, rows [][]string, op TransformOp) ([]string, [][]string) {
	newHeader := make([]string, len(header))
	copy(newHeader, header)
	for i, h := range newHeader {
		if h == op.From {
			newHeader[i] = op.To
			break
		}
	}
	return newHeader, rows
}

func applyDrop(header []string, rows [][]string, op TransformOp) ([]string, [][]string) {
	dropSet := make(map[string]bool)
	for _, c := range op.Columns {
		dropSet[c] = true
	}
	var keepIdx []int
	var newHeader []string
	for i, h := range header {
		if !dropSet[h] {
			keepIdx = append(keepIdx, i)
			newHeader = append(newHeader, h)
		}
	}
	var newRows [][]string
	for _, row := range rows {
		var newRow []string
		for _, idx := range keepIdx {
			if idx < len(row) {
				newRow = append(newRow, row[idx])
			}
		}
		newRows = append(newRows, newRow)
	}
	return newHeader, newRows
}

func applyAggregate(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	for _, gb := range op.GroupBy {
		if colIndex(header, gb) < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", gb)
		}
	}
	for _, agg := range op.Aggregations {
		if colIndex(header, agg.Column) < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", agg.Column)
		}
	}

	type Group struct {
		key  []string
		rows [][]string
	}
	groupMap := make(map[string]*Group)
	var groupKeys []string

	for _, row := range rows {
		var keyParts []string
		for _, gb := range op.GroupBy {
			idx := colIndex(header, gb)
			val := ""
			if idx >= 0 && idx < len(row) {
				val = row[idx]
			}
			keyParts = append(keyParts, val)
		}
		key := strings.Join(keyParts, "\x00")
		if _, exists := groupMap[key]; !exists {
			groupMap[key] = &Group{key: keyParts}
			groupKeys = append(groupKeys, key)
		}
		groupMap[key].rows = append(groupMap[key].rows, row)
	}

	sort.Slice(groupKeys, func(i, j int) bool {
		gi := groupMap[groupKeys[i]]
		gj := groupMap[groupKeys[j]]
		for k := 0; k < len(gi.key) && k < len(gj.key); k++ {
			if gi.key[k] < gj.key[k] {
				return true
			}
			if gi.key[k] > gj.key[k] {
				return false
			}
		}
		return false
	})

	newHeader := make([]string, 0, len(op.GroupBy)+len(op.Aggregations))
	for _, gb := range op.GroupBy {
		newHeader = append(newHeader, gb)
	}
	for _, agg := range op.Aggregations {
		newHeader = append(newHeader, agg.As)
	}

	var resultRows [][]string
	for _, key := range groupKeys {
		group := groupMap[key]
		outRow := make([]string, 0, len(op.GroupBy)+len(op.Aggregations))
		outRow = append(outRow, group.key...)

		for _, agg := range op.Aggregations {
			aggIdx := colIndex(header, agg.Column)
			var numVals []float64
			nonEmptyCount := 0

			for _, r := range group.rows {
				if aggIdx >= 0 && aggIdx < len(r) {
					val := r[aggIdx]
					if val != "" {
						nonEmptyCount++
						if v, err := strconv.ParseFloat(val, 64); err == nil {
							numVals = append(numVals, v)
						}
					}
				}
			}

			var result string
			switch agg.Function {
			case "sum":
				s := 0.0
				for _, v := range numVals {
					s += v
				}
				result = formatFloat(s)
			case "avg":
				if len(numVals) == 0 {
					result = "NaN"
				} else {
					s := 0.0
					for _, v := range numVals {
						s += v
					}
					result = formatFloat(s / float64(len(numVals)))
				}
			case "count":
				result = strconv.Itoa(nonEmptyCount)
			case "min":
				if len(numVals) == 0 {
					result = "NaN"
				} else {
					m := numVals[0]
					for _, v := range numVals[1:] {
						if v < m {
							m = v
						}
					}
					result = formatFloat(m)
				}
			case "max":
				if len(numVals) == 0 {
					result = "NaN"
				} else {
					m := numVals[0]
					for _, v := range numVals[1:] {
						if v > m {
							m = v
						}
					}
					result = formatFloat(m)
				}
			}
			outRow = append(outRow, result)
		}
		resultRows = append(resultRows, outRow)
	}

	// HAVING filter
	if op.Having != nil {
		havIdx := -1
		for i, h := range newHeader {
			if h == op.Having.Column {
				havIdx = i
				break
			}
		}
		if havIdx >= 0 {
			var filtered [][]string
			for _, row := range resultRows {
				val, err := strconv.ParseFloat(row[havIdx], 64)
				if err != nil {
					continue
				}
				keep := false
				switch op.Having.Condition {
				case "gt":
					keep = val > op.Having.Threshold
				case "gte":
					keep = val >= op.Having.Threshold
				case "lt":
					keep = val < op.Having.Threshold
				case "lte":
					keep = val <= op.Having.Threshold
				case "eq":
					keep = val == op.Having.Threshold
				case "neq":
					keep = val != op.Having.Threshold
				}
				if keep {
					filtered = append(filtered, row)
				}
			}
			resultRows = filtered
		}
	}

	return newHeader, resultRows, nil
}

func applyJoin(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	leftKeyIdx := colIndex(header, op.On)
	if leftKeyIdx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: join key %s not found in left dataset", op.On)
	}

	rf, err := os.Open(op.Right)
	if err != nil {
		return nil, nil, fmt.Errorf("ERROR: file not found: %s", op.Right)
	}
	defer rf.Close()

	rReader := csv.NewReader(rf)
	rightRecords, err := rReader.ReadAll()
	if err != nil {
		return nil, nil, fmt.Errorf("ERROR: cannot parse CSV: %s", op.Right)
	}

	if len(rightRecords) == 0 {
		return nil, nil, fmt.Errorf("ERROR: empty right CSV")
	}

	rightHeader := rightRecords[0]
	rightRows := rightRecords[1:]

	rightKeyIdx := colIndex(rightHeader, op.On)
	if rightKeyIdx < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: join key %s not found in right dataset", op.On)
	}

	rightIndex := make(map[string][]string)
	for _, rr := range rightRows {
		key := rr[rightKeyIdx]
		if _, exists := rightIndex[key]; !exists {
			rightIndex[key] = rr
		}
	}

	newHeader := make([]string, len(header))
	copy(newHeader, header)
	var rightColIndices []int
	for i, rh := range rightHeader {
		if i != rightKeyIdx {
			newHeader = append(newHeader, rh)
			rightColIndices = append(rightColIndices, i)
		}
	}

	emptyRight := make([]string, len(rightColIndices))

	var resultRows [][]string
	for _, leftRow := range rows {
		leftKey := leftRow[leftKeyIdx]
		rightRow, found := rightIndex[leftKey]

		if found {
			newRow := make([]string, len(leftRow))
			copy(newRow, leftRow)
			for _, ri := range rightColIndices {
				newRow = append(newRow, rightRow[ri])
			}
			resultRows = append(resultRows, newRow)
		} else if op.JoinType == "left" {
			newRow := make([]string, len(leftRow))
			copy(newRow, leftRow)
			newRow = append(newRow, emptyRight...)
			resultRows = append(resultRows, newRow)
		}
	}

	return newHeader, resultRows, nil
}

// --- Window functions ---

func applyWindow(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	// Validate columns
	for _, col := range op.PartitionBy {
		if colIndex(header, col) < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", col)
		}
	}
	for _, ob := range op.OrderBy {
		if colIndex(header, ob.Column) < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", ob.Column)
		}
	}
	if op.SourceColumn != "" {
		if colIndex(header, op.SourceColumn) < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.SourceColumn)
		}
	}

	type indexedRow struct {
		origIdx int
		row     []string
	}

	// Build partitions
	partMap := make(map[string][]indexedRow)
	var partKeys []string
	for i, row := range rows {
		var keyParts []string
		for _, col := range op.PartitionBy {
			idx := colIndex(header, col)
			val := ""
			if idx >= 0 && idx < len(row) {
				val = row[idx]
			}
			keyParts = append(keyParts, val)
		}
		key := strings.Join(keyParts, "\x00")
		if _, exists := partMap[key]; !exists {
			partKeys = append(partKeys, key)
		}
		partMap[key] = append(partMap[key], indexedRow{origIdx: i, row: row})
	}

	// Sort within each partition by order_by
	for _, key := range partKeys {
		part := partMap[key]
		sort.SliceStable(part, func(i, j int) bool {
			for _, ob := range op.OrderBy {
				idx := colIndex(header, ob.Column)
				a := part[i].row[idx]
				b := part[j].row[idx]
				af, aerr := strconv.ParseFloat(a, 64)
				bf, berr := strconv.ParseFloat(b, 64)
				cmp := 0
				if aerr == nil && berr == nil {
					if af < bf {
						cmp = -1
					} else if af > bf {
						cmp = 1
					}
				} else {
					if a < b {
						cmp = -1
					} else if a > b {
						cmp = 1
					}
				}
				if ob.Order == "desc" {
					cmp = -cmp
				}
				if cmp != 0 {
					return cmp < 0
				}
			}
			return false
		})
		partMap[key] = part
	}

	// Compute window values: map origIdx -> value string
	windowVals := make(map[int]string)

	for _, key := range partKeys {
		part := partMap[key]
		k := len(part)

		switch op.Function {
		case "rank":
			for i := 0; i < k; i++ {
				if i == 0 {
					windowVals[part[i].origIdx] = "1"
				} else {
					same := true
					for _, ob := range op.OrderBy {
						idx := colIndex(header, ob.Column)
						if part[i].row[idx] != part[i-1].row[idx] {
							same = false
							break
						}
					}
					if same {
						windowVals[part[i].origIdx] = windowVals[part[i-1].origIdx]
					} else {
						windowVals[part[i].origIdx] = strconv.Itoa(i + 1)
					}
				}
			}
		case "dense_rank":
			rank := 1
			for i := 0; i < k; i++ {
				if i > 0 {
					same := true
					for _, ob := range op.OrderBy {
						idx := colIndex(header, ob.Column)
						if part[i].row[idx] != part[i-1].row[idx] {
							same = false
							break
						}
					}
					if !same {
						rank++
					}
				}
				windowVals[part[i].origIdx] = strconv.Itoa(rank)
			}
		case "row_number":
			for i := 0; i < k; i++ {
				windowVals[part[i].origIdx] = strconv.Itoa(i + 1)
			}
		case "lag":
			srcIdx := colIndex(header, op.SourceColumn)
			for i := 0; i < k; i++ {
				lookback := i - op.Offset
				if lookback >= 0 {
					windowVals[part[i].origIdx] = part[lookback].row[srcIdx]
				} else {
					windowVals[part[i].origIdx] = op.Default
				}
			}
		case "lead":
			srcIdx := colIndex(header, op.SourceColumn)
			for i := 0; i < k; i++ {
				lookahead := i + op.Offset
				if lookahead < k {
					windowVals[part[i].origIdx] = part[lookahead].row[srcIdx]
				} else {
					windowVals[part[i].origIdx] = op.Default
				}
			}
		case "running_sum":
			srcIdx := colIndex(header, op.SourceColumn)
			cumSum := 0.0
			for i := 0; i < k; i++ {
				val, err := strconv.ParseFloat(part[i].row[srcIdx], 64)
				if err != nil {
					val = 0
				}
				cumSum += val
				windowVals[part[i].origIdx] = formatFloat(cumSum)
			}
		case "running_avg":
			srcIdx := colIndex(header, op.SourceColumn)
			cumSum := 0.0
			numCount := 0
			for i := 0; i < k; i++ {
				val, err := strconv.ParseFloat(part[i].row[srcIdx], 64)
				if err == nil {
					cumSum += val
					numCount++
				}
				if numCount == 0 {
					windowVals[part[i].origIdx] = "NaN"
				} else {
					windowVals[part[i].origIdx] = formatFloat(cumSum / float64(numCount))
				}
			}
		case "ntile":
			n := op.N
			if n <= 0 {
				n = 1
			}
			for i := 0; i < k; i++ {
				// First (k%n) groups have ceil(k/n) rows, rest have floor(k/n)
				bigGroups := k % n
				bigSize := (k + n - 1) / n // ceil(k/n)
				smallSize := k / n
				if bigGroups == 0 {
					bigSize = smallSize
				}
				tile := 0
				pos := 0
				for g := 0; g < n; g++ {
					sz := smallSize
					if g < bigGroups {
						sz = bigSize
					}
					if i >= pos && i < pos+sz {
						tile = g + 1
						break
					}
					pos += sz
				}
				windowVals[part[i].origIdx] = strconv.Itoa(tile)
			}
		}
	}

	// Build output: original row order, append window column
	newHeader := append(append([]string{}, header...), op.As)
	var resultRows [][]string
	for i, row := range rows {
		newRow := append(append([]string{}, row...), windowVals[i])
		resultRows = append(resultRows, newRow)
	}
	return newHeader, resultRows, nil
}

// --- Pivot ---

func applyPivot(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	// Validate columns
	for _, col := range op.Index {
		if colIndex(header, col) < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", col)
		}
	}
	if colIndex(header, op.Column) < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Column)
	}
	if colIndex(header, op.Value) < 0 {
		return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", op.Value)
	}

	colIdx := colIndex(header, op.Column)
	valIdx := colIndex(header, op.Value)

	// Collect unique pivot column values
	pivotValSet := make(map[string]bool)
	var pivotVals []string
	for _, row := range rows {
		pv := row[colIdx]
		if !pivotValSet[pv] {
			pivotValSet[pv] = true
			pivotVals = append(pivotVals, pv)
		}
	}
	sort.Strings(pivotVals)

	// Build index key -> pivot value -> cell value (first wins)
	type cellKey struct {
		indexKey  string
		pivotVal string
	}
	cells := make(map[cellKey]string)
	indexKeySet := make(map[string][]string) // indexKey -> index column values
	var indexKeyOrder []string

	for _, row := range rows {
		var keyParts []string
		for _, col := range op.Index {
			idx := colIndex(header, col)
			keyParts = append(keyParts, row[idx])
		}
		ik := strings.Join(keyParts, "\x00")

		if _, exists := indexKeySet[ik]; !exists {
			indexKeySet[ik] = keyParts
			indexKeyOrder = append(indexKeyOrder, ik)
		}

		ck := cellKey{indexKey: ik, pivotVal: row[colIdx]}
		if _, exists := cells[ck]; !exists {
			cells[ck] = row[valIdx]
		}
	}

	// Sort index keys lexicographically
	sort.Slice(indexKeyOrder, func(i, j int) bool {
		ai := indexKeySet[indexKeyOrder[i]]
		aj := indexKeySet[indexKeyOrder[j]]
		for k := 0; k < len(ai) && k < len(aj); k++ {
			if ai[k] < aj[k] {
				return true
			}
			if ai[k] > aj[k] {
				return false
			}
		}
		return false
	})

	// Build output
	newHeader := make([]string, 0, len(op.Index)+len(pivotVals))
	for _, col := range op.Index {
		newHeader = append(newHeader, col)
	}
	newHeader = append(newHeader, pivotVals...)

	var resultRows [][]string
	for _, ik := range indexKeyOrder {
		outRow := make([]string, 0, len(newHeader))
		outRow = append(outRow, indexKeySet[ik]...)
		for _, pv := range pivotVals {
			ck := cellKey{indexKey: ik, pivotVal: pv}
			if val, exists := cells[ck]; exists {
				outRow = append(outRow, val)
			} else {
				outRow = append(outRow, "")
			}
		}
		resultRows = append(resultRows, outRow)
	}

	return newHeader, resultRows, nil
}

// --- Unpivot ---

func applyUnpivot(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	// Validate columns
	for _, col := range op.Index {
		if colIndex(header, col) < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", col)
		}
	}
	for _, col := range op.Columns {
		if colIndex(header, col) < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", col)
		}
	}

	// Build new header: index columns + name_to + value_to
	newHeader := make([]string, 0, len(op.Index)+2)
	for _, col := range op.Index {
		newHeader = append(newHeader, col)
	}
	newHeader = append(newHeader, op.NameTo, op.ValueTo)

	var resultRows [][]string
	for _, row := range rows {
		for _, meltCol := range op.Columns {
			newRow := make([]string, 0, len(newHeader))
			for _, idxCol := range op.Index {
				idx := colIndex(header, idxCol)
				newRow = append(newRow, row[idx])
			}
			newRow = append(newRow, meltCol)
			idx := colIndex(header, meltCol)
			newRow = append(newRow, row[idx])
			resultRows = append(resultRows, newRow)
		}
	}

	return newHeader, resultRows, nil
}

// --- Expression evaluator ---

var exprFuncNames = map[string]bool{
	"abs": true, "sqrt": true, "ceil": true, "floor": true,
	"round": true, "pow": true, "log": true, "min": true, "max": true, "if": true,
	"clamp": true, "coalesce": true,
}

func tokenize(expr string) []string {
	var tokens []string
	i := 0
	for i < len(expr) {
		ch := expr[i]
		if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
			i++
			continue
		}
		// Two-char operators
		if i+1 < len(expr) {
			two := expr[i : i+2]
			if two == ">=" || two == "<=" || two == "==" || two == "!=" || two == "&&" || two == "||" {
				tokens = append(tokens, two)
				i += 2
				continue
			}
		}
		// Single-char operators
		if ch == '(' || ch == ')' || ch == '+' || ch == '-' || ch == '*' || ch == '/' || ch == '%' || ch == ',' || ch == '>' || ch == '<' {
			tokens = append(tokens, string(ch))
			i++
			continue
		}
		j := i
		for j < len(expr) {
			c := expr[j]
			if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
				break
			}
			if c == '(' || c == ')' || c == '+' || c == '-' || c == '*' || c == '/' || c == '%' || c == ',' || c == '>' || c == '<' || c == '=' || c == '!' || c == '&' || c == '|' {
				break
			}
			j++
		}
		tokens = append(tokens, expr[i:j])
		i = j
	}
	return tokens
}

func evalExpr(expr string, header []string, row []string) float64 {
	tokens := tokenize(expr)
	pos := 0
	return parseExprOr(tokens, &pos, header, row)
}

func parseExprOr(tokens []string, pos *int, header []string, row []string) float64 {
	left := parseExprAnd(tokens, pos, header, row)
	for *pos < len(tokens) && tokens[*pos] == "||" {
		*pos++
		right := parseExprAnd(tokens, pos, header, row)
		if left > 0 || right > 0 {
			left = 1.0
		} else {
			left = 0.0
		}
	}
	return left
}

func parseExprAnd(tokens []string, pos *int, header []string, row []string) float64 {
	left := parseExprEq(tokens, pos, header, row)
	for *pos < len(tokens) && tokens[*pos] == "&&" {
		*pos++
		right := parseExprEq(tokens, pos, header, row)
		if left > 0 && right > 0 {
			left = 1.0
		} else {
			left = 0.0
		}
	}
	return left
}

func parseExprEq(tokens []string, pos *int, header []string, row []string) float64 {
	left := parseExprCmp(tokens, pos, header, row)
	for *pos < len(tokens) && (tokens[*pos] == "==" || tokens[*pos] == "!=") {
		op := tokens[*pos]
		*pos++
		right := parseExprCmp(tokens, pos, header, row)
		if math.IsNaN(left) || math.IsNaN(right) {
			left = 0.0
		} else if op == "==" {
			if left == right {
				left = 1.0
			} else {
				left = 0.0
			}
		} else {
			if left != right {
				left = 1.0
			} else {
				left = 0.0
			}
		}
	}
	return left
}

func parseExprCmp(tokens []string, pos *int, header []string, row []string) float64 {
	left := parseExprAdd(tokens, pos, header, row)
	for *pos < len(tokens) && (tokens[*pos] == ">" || tokens[*pos] == ">=" || tokens[*pos] == "<" || tokens[*pos] == "<=") {
		op := tokens[*pos]
		*pos++
		right := parseExprAdd(tokens, pos, header, row)
		if math.IsNaN(left) || math.IsNaN(right) {
			left = 0.0
		} else {
			switch op {
			case ">":
				if left > right {
					left = 1.0
				} else {
					left = 0.0
				}
			case ">=":
				if left >= right {
					left = 1.0
				} else {
					left = 0.0
				}
			case "<":
				if left < right {
					left = 1.0
				} else {
					left = 0.0
				}
			case "<=":
				if left <= right {
					left = 1.0
				} else {
					left = 0.0
				}
			}
		}
	}
	return left
}

func parseExprAdd(tokens []string, pos *int, header []string, row []string) float64 {
	left := parseExprMul(tokens, pos, header, row)
	for *pos < len(tokens) && (tokens[*pos] == "+" || tokens[*pos] == "-") {
		op := tokens[*pos]
		*pos++
		right := parseExprMul(tokens, pos, header, row)
		if op == "+" {
			left += right
		} else {
			left -= right
		}
	}
	return left
}

func parseExprMul(tokens []string, pos *int, header []string, row []string) float64 {
	left := parseExprUnary(tokens, pos, header, row)
	for *pos < len(tokens) && (tokens[*pos] == "*" || tokens[*pos] == "/" || tokens[*pos] == "%") {
		op := tokens[*pos]
		*pos++
		right := parseExprUnary(tokens, pos, header, row)
		switch op {
		case "*":
			left *= right
		case "/":
			if right == 0 {
				left = math.NaN()
			} else {
				left /= right
			}
		case "%":
			if right == 0 {
				left = math.NaN()
			} else {
				left = math.Mod(left, right)
			}
		}
	}
	return left
}

func parseExprUnary(tokens []string, pos *int, header []string, row []string) float64 {
	if *pos < len(tokens) && tokens[*pos] == "-" {
		*pos++
		val := parseExprUnary(tokens, pos, header, row)
		return -val
	}
	return parseExprAtom(tokens, pos, header, row)
}

func parseExprAtom(tokens []string, pos *int, header []string, row []string) float64 {
	if *pos >= len(tokens) {
		return 0
	}
	tok := tokens[*pos]

	if tok == "(" {
		*pos++
		val := parseExprOr(tokens, pos, header, row)
		if *pos < len(tokens) && tokens[*pos] == ")" {
			*pos++
		}
		return val
	}

	if exprFuncNames[tok] && *pos+1 < len(tokens) && tokens[*pos+1] == "(" {
		funcName := tok
		*pos++ // skip function name
		*pos++ // skip (
		var args []float64
		if *pos < len(tokens) && tokens[*pos] != ")" {
			args = append(args, parseExprOr(tokens, pos, header, row))
			for *pos < len(tokens) && tokens[*pos] == "," {
				*pos++
				args = append(args, parseExprOr(tokens, pos, header, row))
			}
		}
		if *pos < len(tokens) && tokens[*pos] == ")" {
			*pos++
		}
		return evalFunc(funcName, args)
	}

	*pos++
	if v, err := strconv.ParseFloat(tok, 64); err == nil {
		return v
	}
	idx := colIndex(header, tok)
	if idx >= 0 && idx < len(row) {
		if v, err := strconv.ParseFloat(row[idx], 64); err == nil {
			return v
		}
	}
	return 0
}

func evalFunc(name string, args []float64) float64 {
	switch name {
	case "abs":
		if len(args) >= 1 {
			return math.Abs(args[0])
		}
	case "sqrt":
		if len(args) >= 1 {
			if args[0] < 0 {
				return math.NaN()
			}
			return math.Sqrt(args[0])
		}
	case "ceil":
		if len(args) >= 1 {
			return math.Ceil(args[0])
		}
	case "floor":
		if len(args) >= 1 {
			return math.Floor(args[0])
		}
	case "round":
		if len(args) >= 2 {
			n := int(args[1])
			p := math.Pow(10, float64(n))
			return math.Round(args[0]*p) / p
		}
	case "pow":
		if len(args) >= 2 {
			return math.Pow(args[0], args[1])
		}
	case "log":
		if len(args) >= 1 {
			if args[0] <= 0 {
				return math.NaN()
			}
			return math.Log(args[0])
		}
	case "min":
		if len(args) >= 2 {
			return math.Min(args[0], args[1])
		}
	case "max":
		if len(args) >= 2 {
			return math.Max(args[0], args[1])
		}
	case "if":
		if len(args) >= 3 {
			if args[0] > 0 {
				return args[1]
			}
			return args[2]
		}
	case "clamp":
		if len(args) >= 3 {
			x, lo, hi := args[0], args[1], args[2]
			if x < lo {
				return lo
			}
			if x > hi {
				return hi
			}
			return x
		}
	case "coalesce":
		if len(args) >= 2 {
			if math.IsNaN(args[0]) {
				return args[1]
			}
			return args[0]
		}
	}
	return 0
}

// --- Fill transform ---

func applyFill(header []string, rows [][]string, op TransformOp) ([]string, [][]string, error) {
	// Validate columns exist
	var colIndices []int
	for _, c := range op.Columns {
		idx := colIndex(header, c)
		if idx < 0 {
			return nil, nil, fmt.Errorf("ERROR: invalid recipe: column %s not found", c)
		}
		colIndices = append(colIndices, idx)
	}

	// Make a copy of rows to avoid mutating original
	newRows := make([][]string, len(rows))
	for i, row := range rows {
		newRow := make([]string, len(row))
		copy(newRow, row)
		newRows[i] = newRow
	}

	switch op.Strategy {
	case "forward":
		for _, ci := range colIndices {
			last := ""
			hasLast := false
			for i := 0; i < len(newRows); i++ {
				if ci < len(newRows[i]) && newRows[i][ci] != "" {
					last = newRows[i][ci]
					hasLast = true
				} else if hasLast && ci < len(newRows[i]) && newRows[i][ci] == "" {
					newRows[i][ci] = last
				}
			}
		}
	case "backward":
		for _, ci := range colIndices {
			last := ""
			hasLast := false
			for i := len(newRows) - 1; i >= 0; i-- {
				if ci < len(newRows[i]) && newRows[i][ci] != "" {
					last = newRows[i][ci]
					hasLast = true
				} else if hasLast && ci < len(newRows[i]) && newRows[i][ci] == "" {
					newRows[i][ci] = last
				}
			}
		}
	case "constant":
		for _, ci := range colIndices {
			for i := 0; i < len(newRows); i++ {
				if ci < len(newRows[i]) && newRows[i][ci] == "" {
					newRows[i][ci] = op.Value
				}
			}
		}
	}

	return header, newRows, nil
}

// --- Verify ---

func runVerify(args []string) error {
	p := parseArgs(args)
	filePath := p["file"]
	checksumPath := p["checksum"]

	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return fmt.Errorf("ERROR: file not found: %s", filePath)
	}
	if _, err := os.Stat(checksumPath); os.IsNotExist(err) {
		return fmt.Errorf("ERROR: file not found: %s", checksumPath)
	}

	data, _ := os.ReadFile(filePath)
	actual := fmt.Sprintf("%x", sha256.Sum256(data))

	expectedBytes, _ := os.ReadFile(checksumPath)
	expected := strings.TrimSpace(string(expectedBytes))

	if actual == expected {
		fmt.Println("VERIFIED")
		return nil
	}
	fmt.Printf("MISMATCH expected=%s actual=%s\n", expected, actual)
	return fmt.Errorf("verification failed")
}

// --- Manifest ---

func runManifest(args []string) error {
	p := parseArgs(args)
	dirPath := p["dir"]
	outputPath := p["output"]

	type FileEntry struct {
		Path      string `json:"path"`
		SHA256    string `json:"sha256"`
		Rows      int    `json:"rows"`
		SizeBytes int64  `json:"size_bytes"`
	}

	type Manifest struct {
		GeneratedAt string      `json:"generated_at"`
		Files       []FileEntry `json:"files"`
	}

	files := make([]FileEntry, 0)
	filepath.Walk(dirPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() {
			return nil
		}
		if !strings.HasSuffix(path, ".csv") {
			return nil
		}
		relPath, _ := filepath.Rel(dirPath, path)
		data, err := os.ReadFile(path)
		if err != nil {
			return nil
		}
		h := sha256.Sum256(data)
		lines := strings.Count(string(data), "\n")
		if len(data) > 0 && data[len(data)-1] != '\n' {
			lines++
		}
		rows := lines - 1
		if rows < 0 {
			rows = 0
		}
		files = append(files, FileEntry{
			Path:      relPath,
			SHA256:    fmt.Sprintf("%x", h),
			Rows:      rows,
			SizeBytes: info.Size(),
		})
		return nil
	})

	sort.Slice(files, func(i, j int) bool {
		return files[i].Path < files[j].Path
	})

	manifest := Manifest{
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
		Files:       files,
	}

	data, _ := json.MarshalIndent(manifest, "", "  ")
	os.WriteFile(outputPath, data, 0644)
	return nil
}

// --- Pipeline ---

type PipelineStep struct {
	Type     string `json:"type"`
	Input    string `json:"input,omitempty"`
	Schema   string `json:"schema,omitempty"`
	Output   string `json:"output,omitempty"`
	Recipe   string `json:"recipe,omitempty"`
	File     string `json:"file,omitempty"`
	Checksum string `json:"checksum,omitempty"`
	Dir      string `json:"dir,omitempty"`
}

type PipelineConfig struct {
	Seed  uint64         `json:"seed"`
	Steps []PipelineStep `json:"steps"`
}

func runPipeline(args []string) error {
	p := parseArgs(args)
	configPath := p["config"]

	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		return fmt.Errorf("ERROR: file not found: %s", configPath)
	}

	configData, err := os.ReadFile(configPath)
	if err != nil {
		return fmt.Errorf("ERROR: file not found: %s", configPath)
	}

	var config PipelineConfig
	if err := json.Unmarshal(configData, &config); err != nil {
		return fmt.Errorf("ERROR: malformed JSON: %s", configPath)
	}

	for i, step := range config.Steps {
		var stepErr error
		switch step.Type {
		case "ingest":
			stepErr = runIngest([]string{"--input", step.Input, "--schema", step.Schema, "--output", step.Output})
		case "transform":
			stepErr = runTransform([]string{"--input", step.Input, "--recipe", step.Recipe, "--output", step.Output, "--seed", strconv.FormatUint(config.Seed, 10)})
		case "verify":
			stepErr = runVerify([]string{"--file", step.File, "--checksum", step.Checksum})
		case "manifest":
			stepErr = runManifest([]string{"--dir", step.Dir, "--output", step.Output})
		default:
			fmt.Printf("PIPELINE FAILED at step %d: unknown step type %s\n", i+1, step.Type)
			os.Exit(1)
		}
		if stepErr != nil {
			fmt.Printf("PIPELINE FAILED at step %d: %s\n", i+1, stepErr)
			os.Exit(1)
		}
	}

	fmt.Printf("PIPELINE OK: %d steps completed\n", len(config.Steps))
	return nil
}
GOEOF

go build -o dpipe ./...
