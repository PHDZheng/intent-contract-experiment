#!/usr/bin/env bash

# =============================================================================
# Comprehensive test suite for dpipe
# Tests all commands: ingest, transform, verify, manifest, pipeline
# =============================================================================

PASS=0
TOTAL=0

# --- Per-case metadata registry (keyed by the description passed to the
#     check/check_contains/check_approx/skip helpers). origin_step = round
#     that first introduced the requirement (base = pre-round-1 baseline). ---
declare -A CASE_ORIGIN CASE_REQ CASE_TYPE CASE_INTENT CASE_EXPECTED
declare -A ORIGIN_TOTAL ORIGIN_SUCCESS REQ_TOTAL REQ_SUCCESS TYPE_TOTAL TYPE_SUCCESS FAILCAT
CASE_NUM=0
reg() { CASE_ORIGIN["$1"]="$2"; CASE_REQ["$1"]="$3"; CASE_TYPE["$1"]="$4"; CASE_INTENT["$1"]="$5"; CASE_EXPECTED["$1"]="$6"; }
reg "dpipe binary exists and is executable" base build core "Build check" "dpipe binary exists and is executable"
reg "basic ingest: output file exists" round-1 ingest core "Basic ingest" "basic ingest: output file exists"
reg "basic ingest: valid row count is 3" round-1 ingest core "Basic ingest" "basic ingest: valid row count is 3"
reg "basic ingest: rows sorted by id ascending" round-1 ingest core "Basic ingest" "basic ingest: rows sorted by id ascending"
reg "basic ingest: SHA-256 matches" round-1 ingest core "Basic ingest" "basic ingest: SHA-256 matches"
reg "basic ingest: SHA-256 file exists" round-1 ingest core "Basic ingest" "basic ingest: SHA-256 file exists"
reg "basic ingest: rejected file has 2 rows" round-1 ingest core "Basic ingest" "basic ingest: rejected file has 2 rows"
reg "basic ingest: rejected file exists" round-1 ingest core "Basic ingest" "basic ingest: rejected file exists"
reg "composite pk: output file exists" round-1 ingest integration "Composite primary key" "composite pk: output file exists"
reg "composite pk: row count is 6" round-1 ingest integration "Composite primary key" "composite pk: row count is 6"
reg "composite pk: first row region is East" round-1 ingest integration "Composite primary key" "composite pk: first row region is East"
reg "composite pk: first row id is 1" round-1 ingest integration "Composite primary key" "composite pk: first row id is 1"
reg "unique constraint: valid row count is 3" round-1 ingest core "Unique constraint" "unique constraint: valid row count is 3"
reg "unique constraint: rejected file exists" round-1 ingest core "Unique constraint" "unique constraint: rejected file exists"
reg "unique constraint: rejection reason mentions duplicate" round-1 ingest core "Unique constraint" "unique constraint: rejection reason mentions duplicate"
reg "min/max: valid row count is 3" round-1 ingest core "Min/max range constraint" "min/max: valid row count is 3"
reg "min/max: rejected row count is 2" round-1 ingest core "Min/max range constraint" "min/max: rejected row count is 2"
reg "min/max: rejection reason mentions out of range" round-1 ingest core "Min/max range constraint" "min/max: rejection reason mentions out of range"
reg "min/max: rejected file exists" round-1 ingest core "Min/max range constraint" "min/max: rejected file exists"
reg "pattern: valid row count is 3" round-1 ingest core "Pattern constraint" "pattern: valid row count is 3"
reg "pattern: rejected row count is 2" round-1 ingest core "Pattern constraint" "pattern: rejected row count is 2"
reg "pattern: rejection reason mentions pattern" round-1 ingest core "Pattern constraint" "pattern: rejection reason mentions pattern"
reg "pattern: rejected file exists" round-1 ingest core "Pattern constraint" "pattern: rejected file exists"
reg "filter gt 10: row count is 3" round-1 transform.filter core "Transform filter" "filter gt 10: row count is 3"
reg "filter gt 10: all values > 10" round-1 transform.filter core "Transform filter" "filter gt 10: all values > 10"
reg "derive basic: output has computed column" round-1 transform.derive core "Transform derive basic expression" "derive basic: output has computed column"
reg "derive basic: 5*2+1 = 11" round-1 transform.derive core "Transform derive basic expression" "derive basic: 5*2+1 = 11"
reg "func abs(-5) = 5" round-1 transform.derive core "Transform derive with functions" "func abs(-5) = 5"
reg "func sqrt(16) = 4" round-1 transform.derive core "Transform derive with functions" "func sqrt(16) = 4"
reg "func ceil(2.3) = 3" round-1 transform.derive core "Transform derive with functions" "func ceil(2.3) = 3"
reg "func floor(2.7) = 2" round-1 transform.derive core "Transform derive with functions" "func floor(2.7) = 2"
reg "func round(2.345, 2) = 2.35" round-1 transform.derive core "Transform derive with functions" "func round(2.345, 2) = 2.35"
reg "func pow(2, 3) = 8" round-1 transform.derive core "Transform derive with functions" "func pow(2, 3) = 8"
reg "func log(1) = 0" round-1 transform.derive core "Transform derive with functions" "func log(1) = 0"
reg "func min(3, 7) = 3" round-1 transform.derive core "Transform derive with functions" "func min(3, 7) = 3"
reg "func max(3, 7) = 7" round-1 transform.derive core "Transform derive with functions" "func max(3, 7) = 7"
reg "func if(1, 10, 20) = 10" round-1 transform.derive core "Transform derive with functions" "func if(1, 10, 20) = 10"
reg "nested: round(sqrt(abs(-16)), 2) = 4" round-1 transform.derive core "Transform derive with nested functions" "nested: round(sqrt(abs(-16)), 2) = 4"
reg "nested: if(2.3, ceil(2.3), floor(2.3)) = 3" round-1 transform.derive core "Transform derive with nested functions" "nested: if(2.3, ceil(2.3), floor(2.3)) = 3"
reg "edge: sqrt(-1) = NaN" round-1 transform.derive boundary "Derive negative function edge cases" "edge: sqrt(-1) = NaN"
reg "edge: log(0) = NaN" round-1 transform.derive boundary "Derive negative function edge cases" "edge: log(0) = NaN"
reg "edge: if(0, 10, 20) = 20" round-1 transform.derive boundary "Derive negative function edge cases" "edge: if(0, 10, 20) = 20"
reg "sample determinism: same seed same output" round-1 transform.sample integration "Transform sample determinism" "sample determinism: same seed same output"
reg "sort desc: first value is 20" round-1 transform.sort core "Transform sort" "sort desc: first value is 20"
reg "stable sort: first tied row label is 'first'" round-1 transform.sort core "Transform sort" "stable sort: first tied row label is 'first'"
reg "stable sort: second tied row label is 'second'" round-1 transform.sort core "Transform sort" "stable sort: second tied row label is 'second'"
reg "aggregate: 3 groups" round-1 transform.aggregate core "Transform aggregate" "aggregate: 3 groups"
reg "aggregate: group A sum=60" round-1 transform.aggregate core "Transform aggregate" "aggregate: group A sum=60"
reg "aggregate: group A avg=20" round-1 transform.aggregate core "Transform aggregate" "aggregate: group A avg=20"
reg "aggregate: group A count=3" round-1 transform.aggregate core "Transform aggregate" "aggregate: group A count=3"
reg "aggregate: sorted ascending (first group is A)" round-1 transform.aggregate core "Transform aggregate" "aggregate: sorted ascending (first group is A)"
reg "agg min/max: group X min=10" round-1 transform.aggregate core "Transform aggregate min/max" "agg min/max: group X min=10"
reg "agg min/max: group X max=30" round-1 transform.aggregate core "Transform aggregate min/max" "agg min/max: group X max=30"
reg "inner join: row count is 2" round-1 transform.join integration "Transform join inner" "inner join: row count is 2"
reg "inner join: has dept column" round-1 transform.join integration "Transform join inner" "inner join: has dept column"
reg "inner join: has city column" round-1 transform.join integration "Transform join inner" "inner join: has city column"
reg "left join: row count is 3" round-1 transform.join integration "Transform join left" "left join: row count is 3"
reg "left join: unmatched row has empty right column" round-1 transform.join integration "Transform join left" "left join: unmatched row has empty right column"
reg "left join: matched row has correct right value" round-1 transform.join integration "Transform join left" "left join: matched row has correct right value"
reg "verify match: prints VERIFIED" round-1 verify core "Verify" "verify match: prints VERIFIED"
reg "verify match: stdout contains VERIFIED" round-1 verify core "Verify" "verify match: stdout contains VERIFIED"
reg "verify mismatch: exit code 1" round-1 verify core "Verify" "verify mismatch: exit code 1"
reg "verify mismatch: stdout contains MISMATCH" round-1 verify core "Verify" "verify mismatch: stdout contains MISMATCH"
reg "manifest: file count is 2" round-1 manifest integration "Manifest" "manifest: file count is 2"
reg "manifest: has generated_at field" round-1 manifest integration "Manifest" "manifest: has generated_at field"
reg "pipeline success: exit code 0" round-1 pipeline integration "Pipeline success" "pipeline success: exit code 0"
reg "pipeline success: PIPELINE OK message" round-1 pipeline integration "Pipeline success" "pipeline success: PIPELINE OK message"
reg "pipeline failure: exit code 1" round-1 pipeline error "Pipeline failure" "pipeline failure: exit code 1"
reg "pipeline failure: PIPELINE FAILED message" round-1 pipeline error "Pipeline failure" "pipeline failure: PIPELINE FAILED message"
reg "determinism: two identical runs produce same SHA-256" round-1 determinism integration "Determinism" "determinism: two identical runs produce same SHA-256"
reg "determinism: stored SHA-256 files match" round-1 determinism integration "Determinism" "determinism: stored SHA-256 files match"
reg "error: missing file exit code 1" round-1 error-handling error "Error handling" "error: missing file exit code 1"
reg "error: missing file message" round-1 error-handling error "Error handling" "error: missing file message"
reg "error: unknown op exit code 1" round-1 error-handling error "Error handling" "error: unknown op exit code 1"
reg "error: unknown op message" round-1 error-handling error "Error handling" "error: unknown op message"
reg "error: malformed JSON exit code 1" round-1 error-handling error "Error handling" "error: malformed JSON exit code 1"
reg "error: malformed JSON message" round-1 error-handling error "Error handling" "error: malformed JSON message"
reg "error: invalid pattern exit code 1" round-1 error-handling error "Error handling" "error: invalid pattern exit code 1"
reg "error: invalid pattern message" round-1 error-handling error "Error handling" "error: invalid pattern message"
reg "divzero: value/0 = NaN" round-1 transform.derive boundary "Division by zero" "divzero: value/0 = NaN"
reg "modulo: 7 %% 3 = 1" round-1 transform.derive core "Modulo" "modulo: 7 %% 3 = 1"
reg "parens: (2+3)*4 = 20" round-1 transform.derive core "Parentheses" "parens: (2+3)*4 = 20"
reg "join key error: exit code 1" round-1 transform.join error "Join key missing error" "join key error: exit code 1"
reg "join key error: message mentions key not found" round-1 transform.join error "Join key missing error" "join key error: message mentions key not found"
reg "filter lte 15: row count is 3" round-1 transform.filter core "Additional filter conditions" "filter lte 15: row count is 3"
reg "filter neq 10: row count is 4" round-1 transform.filter core "Additional filter conditions" "filter neq 10: row count is 4"
reg "filter eq 10: row count is 1" round-1 transform.filter core "Additional filter conditions" "filter eq 10: row count is 1"
reg "rename: header has category" round-1 transform.rename-drop core "Rename and drop" "rename: header has category"
reg "rename: header does not have label" round-1 transform.rename-drop core "Rename and drop" "rename: header does not have label"
reg "drop: header does not have extra" round-1 transform.rename-drop core "Rename and drop" "drop: header does not have extra"
reg "chain: filter gte 10 keeps 4 rows" round-1 pipeline integration "Chained transform pipeline" "chain: filter gte 10 keeps 4 rows"
reg "chain: first doubled value is 20" round-1 pipeline integration "Chained transform pipeline" "chain: first doubled value is 20"
reg "chain: last doubled value is 70" round-1 pipeline integration "Chained transform pipeline" "chain: last doubled value is 70"
reg "all valid: row count is 3" round-1 ingest core "Ingest all valid" "all valid: row count is 3"
reg "manifest detail: rows count is 3" round-1 manifest integration "Manifest row count and size" "manifest detail: rows count is 3"
reg "manifest detail: size_bytes matches" round-1 manifest integration "Manifest row count and size" "manifest detail: size_bytes matches"
reg "manifest detail: SHA-256 matches" round-1 manifest integration "Manifest row count and size" "manifest detail: SHA-256 matches"
reg "manifest sort: first file is a.csv" round-1 manifest integration "Manifest sorted by path" "manifest sort: first file is a.csv"
reg "required empty: valid row count is 2" round-1 ingest boundary "Ingest required field empty" "required empty: valid row count is 2"
reg "optional empty: valid row count is 2" round-1 ingest boundary "Ingest optional field empty" "optional empty: valid row count is 2"
reg "verify mismatch format: contains expected=" round-1 verify error "Verify MISMATCH format" "verify mismatch format: contains expected="
reg "verify mismatch format: contains actual=" round-1 verify error "Verify MISMATCH format" "verify mismatch format: contains actual="
reg "pipeline step count: mentions 2 steps" round-1 pipeline integration "Pipeline step count" "pipeline step count: mentions 2 steps"
reg "pipeline fail step 2: exit code 1" round-1 pipeline error "Pipeline failure at step 2" "pipeline fail step 2: exit code 1"
reg "pipeline fail step 2: PIPELINE FAILED at step 2" round-1 pipeline error "Pipeline failure at step 2" "pipeline fail step 2: PIPELINE FAILED at step 2"
reg "agg multi: 3 groups" round-1 transform.aggregate integration "Aggregate with multiple groups" "agg multi: 3 groups"
reg "agg multi: first group is food" round-1 transform.aggregate integration "Aggregate with multiple groups" "agg multi: first group is food"
reg "agg multi: food total=35" round-1 transform.aggregate integration "Aggregate with multiple groups" "agg multi: food total=35"
reg "agg avg: group A mean=15" round-1 transform.aggregate boundary "Aggregate avg edge case" "agg avg: group A mean=15"
reg "agg avg: group B mean=NaN (no numeric values)" round-1 transform.aggregate boundary "Aggregate avg edge case" "agg avg: group B mean=NaN (no numeric values)"
reg "join order: first row is Charlie (preserves left order)" round-1 transform.join integration "Join preserves left order" "join order: first row is Charlie (preserves left order)"
reg "join dedup: only 1 output row" round-1 transform.join integration "Join dedup right" "join dedup: only 1 output row"
reg "join dedup: uses first right match (Engineering)" round-1 transform.join integration "Join dedup right" "join dedup: uses first right match (Engineering)"
reg "datetime: valid row count is 2" round-1 ingest core "Ingest datetime validation" "datetime: valid row count is 2"
reg "int type: 3.14 rejected for int column, valid count is 2" round-1 ingest core "Ingest int type validation" "int type: 3.14 rejected for int column, valid count is 2"
reg "transform SHA: checksum matches" round-1 determinism core "Transform SHA-256" "transform SHA: checksum matches"
reg "transform SHA: .sha256 file exists" round-1 determinism core "Transform SHA-256" "transform SHA: .sha256 file exists"
reg "validation order: type-invalid row rejected" round-1 ingest core "Validation order" "validation order: type-invalid row rejected"
reg "agg format: sum 30 not 30.0" round-1 transform.aggregate core "Aggregate formatting" "agg format: sum 30 not 30.0"
reg "agg format: avg 15 not 15.0" round-1 transform.aggregate core "Aggregate formatting" "agg format: avg 15 not 15.0"
reg "agg nonint: avg of 10,20,30 = 20" round-1 transform.aggregate core "Aggregate non-integer avg" "agg nonint: avg of 10,20,30 = 20"
reg "derive sub: 10 - 3 = 7" round-1 transform.derive core "Derive subtraction" "derive sub: 10 - 3 = 7"
reg "derive literal: 10 + 100 = 110" round-1 transform.derive core "Derive with literal numbers" "derive literal: 10 + 100 = 110"
reg "rejected format: has rejection_reason column" round-1 ingest error "Rejected file format" "rejected format: has rejection_reason column"
reg "rejected format: rejected file exists" round-1 ingest error "Rejected file format" "rejected format: rejected file exists"
reg "filter nonexistent col: exit code 1" round-1 transform.filter error "Filter nonexistent column" "filter nonexistent col: exit code 1"
reg "filter nonexistent col: invalid recipe message" round-1 transform.filter error "Filter nonexistent column" "filter nonexistent col: invalid recipe message"
reg "sort nonexistent col: exit code 1" round-1 transform.sort error "Sort nonexistent column" "sort nonexistent col: exit code 1"
reg "sort nonexistent col: invalid recipe message" round-1 transform.sort error "Sort nonexistent column" "sort nonexistent col: invalid recipe message"
reg "pk datetime: first row is earliest date" round-1 ingest core "Primary key sort datetime" "pk datetime: first row is earliest date"
reg "multi derive: has doubled column" round-1 transform.derive core "Multiple derives" "multi derive: has doubled column"
reg "multi derive: has tripled column" round-1 transform.derive core "Multiple derives" "multi derive: has tripled column"
reg "multi derive: tripled = doubled + x = 15" round-1 transform.derive core "Multiple derives" "multi derive: tripled = doubled + x = 15"
reg "minmax float: valid count is 2" round-1 ingest core "Min/max on float column" "minmax float: valid count is 2"
reg "window rank: row count is 6" round-1 transform.window core "Window rank" "window rank: row count is 6"
reg "window rank: header contains rnk" round-1 transform.window core "Window rank" "window rank: header contains rnk"
reg "window rank: row 1 is id=1,A,30,rnk=1" round-1 transform.window core "Window rank" "window rank: row 1 is id=1,A,30,rnk=1"
reg "window rank: row 2 is id=2,A,20,rnk=3" round-1 transform.window core "Window rank" "window rank: row 2 is id=2,A,20,rnk=3"
reg "window dense_rank: row 2 drnk=2" round-1 transform.window core "Window dense_rank" "window dense_rank: row 2 drnk=2"
reg "window dense_rank: row 4 drnk=2" round-1 transform.window core "Window dense_rank" "window dense_rank: row 4 drnk=2"
reg "window row_number: row 2 rn=3" round-1 transform.window core "Window row_number" "window row_number: row 2 rn=3"
reg "window row_number: row 3 rn=2" round-1 transform.window core "Window row_number" "window row_number: row 3 rn=2"
reg "window lag: row 2 prev_val=30" round-1 transform.window core "Window lag" "window lag: row 2 prev_val=30"
reg "window lag: row 5 prev_val=10" round-1 transform.window core "Window lag" "window lag: row 5 prev_val=10"
reg "window lead: row 1 next_val=20" round-1 transform.window core "Window lead" "window lead: row 1 next_val=20"
reg "window lead: row 3 next_val=-1" round-1 transform.window core "Window lead" "window lead: row 3 next_val=-1"
reg "window lead: row 6 next_val=-1" round-1 transform.window core "Window lead" "window lead: row 6 next_val=-1"
reg "window running_sum: row 2 cum_val=50" round-1 transform.window core "Window running_sum" "window running_sum: row 2 cum_val=50"
reg "window running_sum: row 5 cum_val=50" round-1 transform.window core "Window running_sum" "window running_sum: row 5 cum_val=50"
reg "window running_avg: row 2 avg_val=25" round-1 transform.window core "Window running_avg" "window running_avg: row 2 avg_val=25"
reg "window running_avg: row 3 avg_val=26.666666666666668" round-1 transform.window core "Window running_avg" "window running_avg: row 3 avg_val=26.666666666666668"
reg "window ntile: id=3 tile=1" round-1 transform.window core "Window ntile" "window ntile: id=3 tile=1"
reg "window ntile: id=4 tile=2" round-1 transform.window core "Window ntile" "window ntile: id=4 tile=2"
reg "window ntile: id=6 tile=3" round-1 transform.window core "Window ntile" "window ntile: id=6 tile=3"
reg "window no partition: id=1 rnk=3" round-1 transform.window boundary "Window no partition" "window no partition: id=1 rnk=3"
reg "window no partition: id=2 rnk=1" round-1 transform.window boundary "Window no partition" "window no partition: id=2 rnk=1"
reg "window no partition: id=3 rnk=2" round-1 transform.window boundary "Window no partition" "window no partition: id=3 rnk=2"
reg "pivot basic: row count is 3" round-1 transform.pivot core "Pivot basic" "pivot basic: row count is 3"
reg "pivot basic: header is id,height,weight" round-1 transform.pivot core "Pivot basic" "pivot basic: header is id,height,weight"
reg "pivot basic: id=1 row is 1,170,70" round-1 transform.pivot core "Pivot basic" "pivot basic: id=1 row is 1,170,70"
reg "pivot basic: id=3 row has empty weight" round-1 transform.pivot core "Pivot basic" "pivot basic: id=3 row has empty weight"
reg "pivot dedup: header is id,A,B" round-1 transform.pivot core "Pivot dedup" "pivot dedup: header is id,A,B"
reg "pivot dedup: first wins for A column" round-1 transform.pivot core "Pivot dedup" "pivot dedup: first wins for A column"
reg "unpivot basic: row count is 6" round-1 transform.pivot core "Unpivot basic" "unpivot basic: row count is 6"
reg "unpivot basic: header is id,name,quarter,amount" round-1 transform.pivot core "Unpivot basic" "unpivot basic: header is id,name,quarter,amount"
reg "unpivot basic: row 1 is 1,Alice,q1,10" round-1 transform.pivot core "Unpivot basic" "unpivot basic: row 1 is 1,Alice,q1,10"
reg "unpivot basic: row 4 is 2,Bob,q1,40" round-1 transform.pivot core "Unpivot basic" "unpivot basic: row 4 is 2,Bob,q1,40"
reg "unpivot empty: row count is 4" round-1 transform.pivot boundary "Unpivot with empty values" "unpivot empty: row count is 4"
reg "unpivot empty: row 2 has empty val" round-1 transform.pivot boundary "Unpivot with empty values" "unpivot empty: row 2 has empty val"
reg "unpivot empty: row 3 has empty val" round-1 transform.pivot boundary "Unpivot with empty values" "unpivot empty: row 3 has empty val"
reg "window error: exit code 1" round-1 transform.window error "Window error: invalid column" "window error: exit code 1"
reg "window error: message mentions column not found" round-1 transform.window error "Window error: invalid column" "window error: message mentions column not found"
reg "pivot error: exit code 1" round-1 transform.pivot error "Pivot error: invalid column" "pivot error: exit code 1"
reg "pivot error: message mentions column not found" round-1 transform.pivot error "Pivot error: invalid column" "pivot error: message mentions column not found"
reg "unpivot error: exit code 1" round-1 transform.pivot error "Unpivot error: invalid column" "unpivot error: exit code 1"
reg "unpivot error: message mentions column not found" round-1 transform.pivot error "Unpivot error: invalid column" "unpivot error: message mentions column not found"
reg "window multi order: id=1 rnk=2" round-1 transform.window integration "Window multi-column order_by" "window multi order: id=1 rnk=2"
reg "window multi order: id=2 rnk=3" round-1 transform.window integration "Window multi-column order_by" "window multi order: id=2 rnk=3"
reg "window multi order: id=3 rnk=1" round-1 transform.window integration "Window multi-column order_by" "window multi order: id=3 rnk=1"
reg "window multi order: id=4 rnk=4" round-1 transform.window integration "Window multi-column order_by" "window multi order: id=4 rnk=4"
reg "pivot composite: row count is 3" round-1 transform.pivot integration "Pivot with composite index" "pivot composite: row count is 3"
reg "pivot composite: header is year,region,cost,sales" round-1 transform.pivot integration "Pivot with composite index" "pivot composite: header is year,region,cost,sales"
reg "pivot composite: row 1 is 2023,EU,,200" round-1 transform.pivot integration "Pivot with composite index" "pivot composite: row 1 is 2023,EU,,200"
reg "pivot composite: row 2 is 2023,US,80,100" round-1 transform.pivot integration "Pivot with composite index" "pivot composite: row 2 is 2023,US,80,100"
reg "expr cmp: row 1 (15>10=1)" round-1 transform.derive core "Expression comparison operators" "expr cmp: row 1 (15>10=1)"
reg "expr cmp: row 2 (5>10=0)" round-1 transform.derive core "Expression comparison operators" "expr cmp: row 2 (5>10=0)"
reg "expr cmp: row 3 (10>10=0)" round-1 transform.derive core "Expression comparison operators" "expr cmp: row 3 (10>10=0)"
reg "expr logical AND: row 1 (15 in 5..20)" round-1 transform.derive core "Expression logical operators" "expr logical AND: row 1 (15 in 5..20)"
reg "expr logical AND: row 2 (5 not in 5..20)" round-1 transform.derive core "Expression logical operators" "expr logical AND: row 2 (5 not in 5..20)"
reg "expr logical AND: row 3 (10 in 5..20)" round-1 transform.derive core "Expression logical operators" "expr logical AND: row 3 (10 in 5..20)"
reg "expr logical AND: row 4 (25 not in 5..20)" round-1 transform.derive core "Expression logical operators" "expr logical AND: row 4 (25 not in 5..20)"
reg "expr OR: row 2 (5<10=true)" round-1 transform.derive core "Expression OR operator" "expr OR: row 2 (5<10=true)"
reg "expr OR: row 4 (25>20=true)" round-1 transform.derive core "Expression OR operator" "expr OR: row 4 (25>20=true)"
reg "expr eq: row 3 (10==10=1)" round-1 transform.derive core "Expression equality operators" "expr eq: row 3 (10==10=1)"
reg "expr eq: row 1 (15==10=0)" round-1 transform.derive core "Expression equality operators" "expr eq: row 1 (15==10=0)"
reg "expr neq: row 3 (10!=10=0)" round-1 transform.derive core "Expression != operator" "expr neq: row 3 (10!=10=0)"
reg "expr neq: row 2 (5!=10=1)" round-1 transform.derive core "Expression != operator" "expr neq: row 2 (5!=10=1)"
reg "expr precedence: (10+5)>12=1" round-1 transform.derive core "Expression operator precedence" "expr precedence: (10+5)>12=1"
reg "expr negation: -5 from 5" round-1 transform.derive core "Expression unary negation" "expr negation: -5 from 5"
reg "expr negation: 3 from -3" round-1 transform.derive core "Expression unary negation" "expr negation: 3 from -3"
reg "clamp: 5 clamped to 10" round-1 transform.derive core "Clamp function" "clamp: 5 clamped to 10"
reg "clamp: 15 stays 15" round-1 transform.derive core "Clamp function" "clamp: 15 stays 15"
reg "clamp: 25 clamped to 20" round-1 transform.derive core "Clamp function" "clamp: 25 clamped to 20"
reg "coalesce: NaN replaced with -1" round-1 transform.derive core "Coalesce function" "coalesce: NaN replaced with -1"
reg "coalesce: valid 3 kept" round-1 transform.derive core "Coalesce function" "coalesce: valid 3 kept"
reg "NaN cmp: NaN>5=0" round-1 transform.derive boundary "NaN in comparisons" "NaN cmp: NaN>5=0"
reg "having gte 20: row count=3" round-1 transform.aggregate core "Having in aggregate" "having gte 20: row count=3"
reg "having gte 20: row 1=A,60" round-1 transform.aggregate core "Having in aggregate" "having gte 20: row 1=A,60"
reg "having gt 50: row count=2" round-1 transform.aggregate core "Having filters groups" "having gt 50: row count=2"
reg "having gt 50: row 1=A,60" round-1 transform.aggregate core "Having filters groups" "having gt 50: row 1=A,60"
reg "having gt 50: row 2=C,100" round-1 transform.aggregate core "Having filters groups" "having gt 50: row 2=C,100"
reg "fill forward: row 2=2,10" round-1 transform.fill core "Fill forward" "fill forward: row 2=2,10"
reg "fill forward: row 3=3,10" round-1 transform.fill core "Fill forward" "fill forward: row 3=3,10"
reg "fill forward: row 5=5,20" round-1 transform.fill core "Fill forward" "fill forward: row 5=5,20"
reg "fill backward: row 2=2,20" round-1 transform.fill core "Fill backward" "fill backward: row 2=2,20"
reg "fill backward: row 3=3,20" round-1 transform.fill core "Fill backward" "fill backward: row 3=3,20"
reg "fill backward: row 5=5," round-1 transform.fill core "Fill backward" "fill backward: row 5=5,"
reg "fill constant: row 2=2,0" round-1 transform.fill core "Fill constant" "fill constant: row 2=2,0"
reg "fill constant: row 5=5,0" round-1 transform.fill core "Fill constant" "fill constant: row 5=5,0"
reg "fill forward leading: row 1=1," round-1 transform.fill boundary "Fill forward leading empty" "fill forward leading: row 1=1,"
reg "fill forward leading: row 3=3,10" round-1 transform.fill boundary "Fill forward leading empty" "fill forward leading: row 3=3,10"
reg "fill error: exit code 1" round-1 transform.fill error "Fill error: invalid column" "fill error: exit code 1"
reg "fill error: column nonexistent not found" round-1 transform.fill error "Fill error: invalid column" "fill error: column nonexistent not found"
reg "complex expr: row 1 (10>5 && 2!=0 -> 10/2=5)" round-1 transform.derive core "Complex expression with all operator types" "complex expr: row 1 (10>5 && 2!=0 -> 10/2=5)"
reg "complex expr: row 2 (5>5=false -> -1)" round-1 transform.derive core "Complex expression with all operator types" "complex expr: row 2 (5>5=false -> -1)"

# Sanitize free-text field values: collapse whitespace, neutralize any literal
# "status=" so the canonical status= token only ever comes from this script.
_san() { printf '%s' "$1" | tr '\n\r\t' '   ' | sed 's/status=/status:/g' | cut -c1-200; }

# Emit one canonical CASE_RESULT line + per-origin/requirement/type tallies.
# Called by the test helpers after their existing decision; does NOT change it.
_emit_case() {
  local name="$1" status="$2" detail="$3"
  CASE_NUM=$((CASE_NUM + 1))
  local cid; cid=$(printf 'c%03d' "$CASE_NUM")
  local origin="${CASE_ORIGIN[$name]:-round-1}"
  local req="${CASE_REQ[$name]:-unspecified}"
  local ctype="${CASE_TYPE[$name]:-core}"
  local intent="${CASE_INTENT[$name]:-$name}"
  local expected="${CASE_EXPECTED[$name]:-n/a}"
  local actual
  if [ "$status" = "success" ]; then
    actual="matched expectation"; detail=""
  else
    actual="$(_san "$detail")"
    FAILCAT["$req"]=$(( ${FAILCAT["$req"]:-0} + 1 ))
  fi
  ORIGIN_TOTAL["$origin"]=$(( ${ORIGIN_TOTAL["$origin"]:-0} + 1 ))
  REQ_TOTAL["$req"]=$(( ${REQ_TOTAL["$req"]:-0} + 1 ))
  TYPE_TOTAL["$ctype"]=$(( ${TYPE_TOTAL["$ctype"]:-0} + 1 ))
  if [ "$status" = "success" ]; then
    ORIGIN_SUCCESS["$origin"]=$(( ${ORIGIN_SUCCESS["$origin"]:-0} + 1 ))
    REQ_SUCCESS["$req"]=$(( ${REQ_SUCCESS["$req"]:-0} + 1 ))
    TYPE_SUCCESS["$ctype"]=$(( ${TYPE_SUCCESS["$ctype"]:-0} + 1 ))
  fi
  printf 'CASE_RESULT case_id=%s origin_step=%s requirement_ref=%s case_type=%s status=%s intent="%s" scenario="%s" input="%s" expected="%s" actual="%s" failure_reason="%s"\n' \
    "$cid" "$origin" "$req" "$ctype" "$status" "$(_san "$intent")" "$(_san "$name")" "n/a" "$(_san "$expected")" "$actual" "$(_san "$detail")"
}

check() {
  TOTAL=$((TOTAL + 1))
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    _emit_case "$desc" success ""
  else
    _emit_case "$desc" fail "expected=$expected actual=$actual"
  fi
}

check_contains() {
  TOTAL=$((TOTAL + 1))
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
    _emit_case "$desc" success ""
  else
    _emit_case "$desc" fail "expected to contain: $needle | actual: $haystack"
  fi
}

BUILD_OK=0
if [ -x /app/dpipe ]; then BUILD_OK=1; fi

skip() {
  TOTAL=$((TOTAL + 1))
  _emit_case "$1" fail "skipped: build failed"
}

DPIPE=/app/dpipe

# =============================================================================
# 1. Build check
# =============================================================================
echo "=== 1. Build check ==="
check "dpipe binary exists and is executable" "1" "$BUILD_OK"

# =============================================================================
# 2. Basic ingest
# =============================================================================
echo ""
echo "=== 2. Basic ingest ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_basic_ingest
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value,label,timestamp
3,30.5,,2024-01-03T00:00:00Z
1,10.0,Alpha,2024-01-01T00:00:00Z
4,notanumber,Beta,2024-01-04T00:00:00Z
2,20.0,Gamma,2024-01-02T00:00:00Z
5,50.0,Delta,bad-date
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "value", "type": "float", "required": true},
    {"name": "label", "type": "string", "required": false},
    {"name": "timestamp", "type": "datetime", "required": true}
  ],
  "primary_key": ["id"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  # Check output file exists
  if [ -f "$DIR/output.csv" ]; then
    check "basic ingest: output file exists" "1" "1"
  else
    check "basic ingest: output file exists" "1" "0"
  fi

  # Check row count (rows 1,2,3 valid; rows 4,5 invalid)
  ROW_COUNT=$(tail -n +2 "$DIR/output.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "basic ingest: valid row count is 3" "3" "$ROW_COUNT"

  # Check rows sorted by id ascending (numeric)
  FIRST_ID=$(tail -n +2 "$DIR/output.csv" | head -1 | cut -d',' -f1)
  SECOND_ID=$(tail -n +2 "$DIR/output.csv" | sed -n '2p' | cut -d',' -f1)
  THIRD_ID=$(tail -n +2 "$DIR/output.csv" | sed -n '3p' | cut -d',' -f1)
  SORTED="1"
  if [ "$FIRST_ID" != "1" ] || [ "$SECOND_ID" != "2" ] || [ "$THIRD_ID" != "3" ]; then
    SORTED="0"
  fi
  check "basic ingest: rows sorted by id ascending" "1" "$SORTED"

  # Check SHA-256 file exists and matches
  if [ -f "$DIR/output.csv.sha256" ]; then
    COMPUTED_SHA=$(sha256sum "$DIR/output.csv" | awk '{print $1}')
    STORED_SHA=$(tr -d '[:space:]' < "$DIR/output.csv.sha256")
    check "basic ingest: SHA-256 matches" "$COMPUTED_SHA" "$STORED_SHA"
  else
    check "basic ingest: SHA-256 file exists" "1" "0"
  fi

  # Check rejected file exists
  if [ -f "$DIR/output.csv.rejected" ]; then
    REJECTED_COUNT=$(tail -n +2 "$DIR/output.csv.rejected" | wc -l | tr -d ' ')
    check "basic ingest: rejected file has 2 rows" "2" "$REJECTED_COUNT"
  else
    check "basic ingest: rejected file exists" "1" "0"
  fi
else
  skip "basic ingest: output file exists"
  skip "basic ingest: valid row count is 3"
  skip "basic ingest: rows sorted by id ascending"
  skip "basic ingest: SHA-256 matches"
  skip "basic ingest: rejected file has 2 rows"
fi

# =============================================================================
# 3. Composite primary key
# =============================================================================
echo ""
echo "=== 3. Composite primary key ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_composite_pk
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
region,id,name,score
West,2,Alice,80.0
East,1,Bob,90.0
East,3,Charlie,70.0
West,1,Diana,85.0
East,2,Eve,95.0
West,3,Frank,75.0
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "region", "type": "string", "required": true},
    {"name": "id", "type": "int", "required": true},
    {"name": "name", "type": "string", "required": true},
    {"name": "score", "type": "float", "required": true}
  ],
  "primary_key": ["region", "id"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  # Check output exists
  if [ -f "$DIR/output.csv" ]; then
    check "composite pk: output file exists" "1" "1"
  else
    check "composite pk: output file exists" "1" "0"
  fi

  # Check row count (all 6 are valid)
  ROW_COUNT=$(tail -n +2 "$DIR/output.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "composite pk: row count is 6" "6" "$ROW_COUNT"

  # Check first row after header: should be East,1 (lexicographic on region, then numeric on id)
  FIRST_ROW=$(tail -n +2 "$DIR/output.csv" | head -1)
  FIRST_REGION=$(echo "$FIRST_ROW" | cut -d',' -f1)
  FIRST_PK_ID=$(echo "$FIRST_ROW" | cut -d',' -f2)
  check "composite pk: first row region is East" "East" "$FIRST_REGION"
  check "composite pk: first row id is 1" "1" "$FIRST_PK_ID"
else
  skip "composite pk: output file exists"
  skip "composite pk: row count is 6"
  skip "composite pk: first row region is East"
  skip "composite pk: first row id is 1"
fi

# =============================================================================
# 4. Unique constraint
# =============================================================================
echo ""
echo "=== 4. Unique constraint ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_unique
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,code,value
1,AAA,10
2,BBB,20
3,AAA,30
4,CCC,40
5,BBB,50
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "code", "type": "string", "required": true, "unique": true},
    {"name": "value", "type": "int", "required": true}
  ],
  "primary_key": ["id"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  # Rows 3 and 5 are duplicates of code AAA and BBB respectively
  VALID_COUNT=$(tail -n +2 "$DIR/output.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "unique constraint: valid row count is 3" "3" "$VALID_COUNT"

  # Check rejected file exists
  if [ -f "$DIR/output.csv.rejected" ]; then
    check "unique constraint: rejected file exists" "1" "1"
    REJECT_CONTENT=$(cat "$DIR/output.csv.rejected" 2>/dev/null)
    check_contains "unique constraint: rejection reason mentions duplicate" "duplicate value for unique column" "$REJECT_CONTENT"
  else
    check "unique constraint: rejected file exists" "1" "0"
    check "unique constraint: rejection reason mentions duplicate" "should exist" ""
  fi
else
  skip "unique constraint: valid row count is 3"
  skip "unique constraint: rejected file exists"
  skip "unique constraint: rejection reason mentions duplicate"
fi

# =============================================================================
# 5. Min/max range constraint
# =============================================================================
echo ""
echo "=== 5. Min/max range constraint ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_minmax
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,score
1,50
2,-10
3,100
4,150
5,0
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "score", "type": "int", "required": true, "min": 0, "max": 100}
  ],
  "primary_key": ["id"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  # Rows 2 (-10 < 0) and 4 (150 > 100) are out of range; rows 1,3,5 are valid
  VALID_COUNT=$(tail -n +2 "$DIR/output.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "min/max: valid row count is 3" "3" "$VALID_COUNT"

  if [ -f "$DIR/output.csv.rejected" ]; then
    REJECTED_COUNT=$(tail -n +2 "$DIR/output.csv.rejected" | wc -l | tr -d ' ')
    check "min/max: rejected row count is 2" "2" "$REJECTED_COUNT"
    REJECT_CONTENT=$(cat "$DIR/output.csv.rejected" 2>/dev/null)
    check_contains "min/max: rejection reason mentions out of range" "value out of range" "$REJECT_CONTENT"
  else
    check "min/max: rejected file exists" "1" "0"
    check "min/max: rejection reason mentions out of range" "should exist" ""
  fi
else
  skip "min/max: valid row count is 3"
  skip "min/max: rejected row count is 2"
  skip "min/max: rejection reason mentions out of range"
fi

# =============================================================================
# 6. Pattern constraint
# =============================================================================
echo ""
echo "=== 6. Pattern constraint ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pattern
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,code
1,ABC-1234
2,ab-1234
3,XYZ-5678
4,ABC12345
5,DEF-0001
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "code", "type": "string", "required": true, "pattern": "^[A-Z]{3}-\\d{4}$"}
  ],
  "primary_key": ["id"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  # Rows 1,3,5 match pattern; rows 2,4 do not
  VALID_COUNT=$(tail -n +2 "$DIR/output.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "pattern: valid row count is 3" "3" "$VALID_COUNT"

  if [ -f "$DIR/output.csv.rejected" ]; then
    REJECTED_COUNT=$(tail -n +2 "$DIR/output.csv.rejected" | wc -l | tr -d ' ')
    check "pattern: rejected row count is 2" "2" "$REJECTED_COUNT"
    REJECT_CONTENT=$(cat "$DIR/output.csv.rejected" 2>/dev/null)
    check_contains "pattern: rejection reason mentions pattern" "does not match pattern" "$REJECT_CONTENT"
  else
    check "pattern: rejected file exists" "1" "0"
    check "pattern: rejection reason mentions pattern" "should exist" ""
  fi
else
  skip "pattern: valid row count is 3"
  skip "pattern: rejected row count is 2"
  skip "pattern: rejection reason mentions pattern"
fi

# =============================================================================
# 7. Transform filter
# =============================================================================
echo ""
echo "=== 7. Transform filter ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_filter
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value,label
1,5,a
2,15,b
3,25,c
4,10,d
5,35,e
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "filter", "column": "value", "condition": "gt", "threshold": 10}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  FILTER_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "filter gt 10: row count is 3" "3" "$FILTER_COUNT"

  # All remaining values should be > 10
  ALL_GT="1"
  while IFS= read -r line; do
    VAL=$(echo "$line" | cut -d',' -f2)
    if [ "$(echo "$VAL <= 10" | bc 2>/dev/null)" = "1" ]; then
      ALL_GT="0"
    fi
  done < <(tail -n +2 "$DIR/out.csv" 2>/dev/null)
  check "filter gt 10: all values > 10" "1" "$ALL_GT"
else
  skip "filter gt 10: row count is 3"
  skip "filter gt 10: all values > 10"
fi

# =============================================================================
# 8. Transform derive basic expression
# =============================================================================
echo ""
echo "=== 8. Transform derive basic expression ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_derive_basic
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,5
2,10
3,20
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "computed", "expression": "value * 2 + 1"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv" 2>/dev/null)
  check_contains "derive basic: output has computed column" "computed" "$HEADER"

  # value=5 -> 5*2+1 = 11
  FIRST_VAL=$(tail -n +2 "$DIR/out.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "derive basic: 5*2+1 = 11" "11" "$FIRST_VAL"
else
  skip "derive basic: output has computed column"
  skip "derive basic: 5*2+1 = 11"
fi

# =============================================================================
# 9. Transform derive with functions
# =============================================================================
echo ""
echo "=== 9. Transform derive with functions ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_derive_func
  mkdir -p "$DIR"

  # --- abs ---
  cat > "$DIR/input_abs.csv" << 'EOF'
id,value
1,-5
EOF
  cat > "$DIR/recipe_abs.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "abs(value)"}]
EOF
  $DPIPE transform --input "$DIR/input_abs.csv" --recipe "$DIR/recipe_abs.json" --output "$DIR/out_abs.csv" --seed 42 2>/dev/null
  ABS_VAL=$(tail -n +2 "$DIR/out_abs.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "func abs(-5) = 5" "5" "$ABS_VAL"

  # --- sqrt ---
  cat > "$DIR/input_sqrt.csv" << 'EOF'
id,value
1,16
EOF
  cat > "$DIR/recipe_sqrt.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "sqrt(value)"}]
EOF
  $DPIPE transform --input "$DIR/input_sqrt.csv" --recipe "$DIR/recipe_sqrt.json" --output "$DIR/out_sqrt.csv" --seed 42 2>/dev/null
  SQRT_VAL=$(tail -n +2 "$DIR/out_sqrt.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "func sqrt(16) = 4" "4" "$SQRT_VAL"

  # --- ceil ---
  cat > "$DIR/input_ceil.csv" << 'EOF'
id,value
1,2.3
EOF
  cat > "$DIR/recipe_ceil.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "ceil(value)"}]
EOF
  $DPIPE transform --input "$DIR/input_ceil.csv" --recipe "$DIR/recipe_ceil.json" --output "$DIR/out_ceil.csv" --seed 42 2>/dev/null
  CEIL_VAL=$(tail -n +2 "$DIR/out_ceil.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "func ceil(2.3) = 3" "3" "$CEIL_VAL"

  # --- floor ---
  cat > "$DIR/input_floor.csv" << 'EOF'
id,value
1,2.7
EOF
  cat > "$DIR/recipe_floor.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "floor(value)"}]
EOF
  $DPIPE transform --input "$DIR/input_floor.csv" --recipe "$DIR/recipe_floor.json" --output "$DIR/out_floor.csv" --seed 42 2>/dev/null
  FLOOR_VAL=$(tail -n +2 "$DIR/out_floor.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "func floor(2.7) = 2" "2" "$FLOOR_VAL"

  # --- round ---
  cat > "$DIR/input_round.csv" << 'EOF'
id,value
1,2.345
EOF
  cat > "$DIR/recipe_round.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "round(value, 2)"}]
EOF
  $DPIPE transform --input "$DIR/input_round.csv" --recipe "$DIR/recipe_round.json" --output "$DIR/out_round.csv" --seed 42 2>/dev/null
  ROUND_VAL=$(tail -n +2 "$DIR/out_round.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "func round(2.345, 2) = 2.35" "2.35" "$ROUND_VAL"

  # --- pow ---
  cat > "$DIR/input_pow.csv" << 'EOF'
id,base,exp
1,2,3
EOF
  cat > "$DIR/recipe_pow.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "pow(base, exp)"}]
EOF
  $DPIPE transform --input "$DIR/input_pow.csv" --recipe "$DIR/recipe_pow.json" --output "$DIR/out_pow.csv" --seed 42 2>/dev/null
  POW_VAL=$(tail -n +2 "$DIR/out_pow.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "func pow(2, 3) = 8" "8" "$POW_VAL"

  # --- log ---
  cat > "$DIR/input_log.csv" << 'EOF'
id,value
1,1
EOF
  cat > "$DIR/recipe_log.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "log(value)"}]
EOF
  $DPIPE transform --input "$DIR/input_log.csv" --recipe "$DIR/recipe_log.json" --output "$DIR/out_log.csv" --seed 42 2>/dev/null
  LOG_VAL=$(tail -n +2 "$DIR/out_log.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "func log(1) = 0" "0" "$LOG_VAL"

  # --- min ---
  cat > "$DIR/input_min.csv" << 'EOF'
id,a,b
1,3,7
EOF
  cat > "$DIR/recipe_min.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "min(a, b)"}]
EOF
  $DPIPE transform --input "$DIR/input_min.csv" --recipe "$DIR/recipe_min.json" --output "$DIR/out_min.csv" --seed 42 2>/dev/null
  MIN_VAL=$(tail -n +2 "$DIR/out_min.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "func min(3, 7) = 3" "3" "$MIN_VAL"

  # --- max ---
  cat > "$DIR/input_max.csv" << 'EOF'
id,a,b
1,3,7
EOF
  cat > "$DIR/recipe_max.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "max(a, b)"}]
EOF
  $DPIPE transform --input "$DIR/input_max.csv" --recipe "$DIR/recipe_max.json" --output "$DIR/out_max.csv" --seed 42 2>/dev/null
  MAX_VAL=$(tail -n +2 "$DIR/out_max.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "func max(3, 7) = 7" "7" "$MAX_VAL"

  # --- if (condition > 0 => true) ---
  cat > "$DIR/input_if.csv" << 'EOF'
id,cond
1,1
EOF
  cat > "$DIR/recipe_if.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "if(cond, 10, 20)"}]
EOF
  $DPIPE transform --input "$DIR/input_if.csv" --recipe "$DIR/recipe_if.json" --output "$DIR/out_if.csv" --seed 42 2>/dev/null
  IF_VAL=$(tail -n +2 "$DIR/out_if.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "func if(1, 10, 20) = 10" "10" "$IF_VAL"
else
  skip "func abs(-5) = 5"
  skip "func sqrt(16) = 4"
  skip "func ceil(2.3) = 3"
  skip "func floor(2.7) = 2"
  skip "func round(2.345, 2) = 2.35"
  skip "func pow(2, 3) = 8"
  skip "func log(1) = 0"
  skip "func min(3, 7) = 3"
  skip "func max(3, 7) = 7"
  skip "func if(1, 10, 20) = 10"
fi

# =============================================================================
# 10. Transform derive with nested functions
# =============================================================================
echo ""
echo "=== 10. Transform derive with nested functions ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_derive_nested
  mkdir -p "$DIR"

  # round(sqrt(abs(value)), 2) with value=-16 => round(sqrt(16), 2) => round(4, 2) => 4
  cat > "$DIR/input.csv" << 'EOF'
id,value
1,-16
EOF
  cat > "$DIR/recipe_nested1.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "round(sqrt(abs(value)), 2)"}]
EOF
  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe_nested1.json" --output "$DIR/out1.csv" --seed 42 2>/dev/null
  NESTED1_VAL=$(tail -n +2 "$DIR/out1.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "nested: round(sqrt(abs(-16)), 2) = 4" "4" "$NESTED1_VAL"

  # if(value, ceil(value), floor(value)) with value=2.3 => cond=2.3 > 0 => ceil(2.3) = 3
  cat > "$DIR/input2.csv" << 'EOF'
id,value
1,2.3
EOF
  cat > "$DIR/recipe_nested2.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "if(value, ceil(value), floor(value))"}]
EOF
  $DPIPE transform --input "$DIR/input2.csv" --recipe "$DIR/recipe_nested2.json" --output "$DIR/out2.csv" --seed 42 2>/dev/null
  NESTED2_VAL=$(tail -n +2 "$DIR/out2.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "nested: if(2.3, ceil(2.3), floor(2.3)) = 3" "3" "$NESTED2_VAL"
else
  skip "nested: round(sqrt(abs(-16)), 2) = 4"
  skip "nested: if(2.3, ceil(2.3), floor(2.3)) = 3"
fi

# =============================================================================
# 11. Transform derive negative function edge cases
# =============================================================================
echo ""
echo "=== 11. Derive negative function edge cases ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_derive_edge
  mkdir -p "$DIR"

  # sqrt(-1) => NaN
  cat > "$DIR/input.csv" << 'EOF'
id,value
1,-1
EOF
  cat > "$DIR/recipe_sqrt_neg.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "sqrt(value)"}]
EOF
  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe_sqrt_neg.json" --output "$DIR/out_sqrt_neg.csv" --seed 42 2>/dev/null
  SQRT_NEG=$(tail -n +2 "$DIR/out_sqrt_neg.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "edge: sqrt(-1) = NaN" "NaN" "$SQRT_NEG"

  # log(0) => NaN (non-positive)
  cat > "$DIR/input_log0.csv" << 'EOF'
id,value
1,0
EOF
  cat > "$DIR/recipe_log0.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "log(value)"}]
EOF
  $DPIPE transform --input "$DIR/input_log0.csv" --recipe "$DIR/recipe_log0.json" --output "$DIR/out_log0.csv" --seed 42 2>/dev/null
  LOG0_VAL=$(tail -n +2 "$DIR/out_log0.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "edge: log(0) = NaN" "NaN" "$LOG0_VAL"

  # if(0, 10, 20) => 20 (0 is not > 0)
  cat > "$DIR/input_if0.csv" << 'EOF'
id,cond
1,0
EOF
  cat > "$DIR/recipe_if0.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "if(cond, 10, 20)"}]
EOF
  $DPIPE transform --input "$DIR/input_if0.csv" --recipe "$DIR/recipe_if0.json" --output "$DIR/out_if0.csv" --seed 42 2>/dev/null
  IF0_VAL=$(tail -n +2 "$DIR/out_if0.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "edge: if(0, 10, 20) = 20" "20" "$IF0_VAL"
else
  skip "edge: sqrt(-1) = NaN"
  skip "edge: log(0) = NaN"
  skip "edge: if(0, 10, 20) = 20"
fi

# =============================================================================
# 12. Transform sample determinism
# =============================================================================
echo ""
echo "=== 12. Transform sample determinism ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_sample
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,20
3,30
4,40
5,50
6,60
7,70
8,80
9,90
10,100
11,110
12,120
13,130
14,140
15,150
16,160
17,170
18,180
19,190
20,200
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "sample", "fraction": 0.5}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out1.csv" --seed 99999 2>/dev/null
  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out2.csv" --seed 99999 2>/dev/null

  SHA1=$(sha256sum "$DIR/out1.csv" 2>/dev/null | awk '{print $1}')
  SHA2=$(sha256sum "$DIR/out2.csv" 2>/dev/null | awk '{print $1}')
  check "sample determinism: same seed same output" "$SHA1" "$SHA2"
else
  skip "sample determinism: same seed same output"
fi

# =============================================================================
# 13. Transform sort (desc + stable sort with ties)
# =============================================================================
echo ""
echo "=== 13. Transform sort ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_sort
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value,label
1,10,first
2,10,second
3,10,third
4,20,fourth
5,5,fifth
EOF

  # Sort desc
  cat > "$DIR/recipe_desc.json" << 'EOF'
[{"op": "sort", "column": "value", "order": "desc"}]
EOF
  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe_desc.json" --output "$DIR/out_desc.csv" --seed 42 2>/dev/null
  FIRST_VAL=$(tail -n +2 "$DIR/out_desc.csv" | head -1 | cut -d',' -f2)
  check "sort desc: first value is 20" "20" "$FIRST_VAL"

  # Stable sort: ties in value=10, original order preserved (first, second, third)
  cat > "$DIR/recipe_asc.json" << 'EOF'
[{"op": "sort", "column": "value", "order": "asc"}]
EOF
  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe_asc.json" --output "$DIR/out_asc.csv" --seed 42 2>/dev/null
  # value=5 first, then 10 (three rows in original order), then 20
  SECOND_LABEL=$(tail -n +2 "$DIR/out_asc.csv" | sed -n '2p' | cut -d',' -f3)
  THIRD_LABEL=$(tail -n +2 "$DIR/out_asc.csv" | sed -n '3p' | cut -d',' -f3)
  check "stable sort: first tied row label is 'first'" "first" "$SECOND_LABEL"
  check "stable sort: second tied row label is 'second'" "second" "$THIRD_LABEL"
else
  skip "sort desc: first value is 20"
  skip "stable sort: first tied row label is 'first'"
  skip "stable sort: second tied row label is 'second'"
fi

# =============================================================================
# 14. Transform aggregate
# =============================================================================
echo ""
echo "=== 14. Transform aggregate ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_aggregate
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,group,value
1,A,10
2,A,20
3,A,30
4,B,40
5,B,60
6,C,100
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "aggregate", "group_by": ["group"], "aggregations": [
  {"column": "value", "function": "sum", "as": "total"},
  {"column": "value", "function": "avg", "as": "average"},
  {"column": "id", "function": "count", "as": "cnt"}
]}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # Should have 3 groups: A, B, C
  GROUP_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "aggregate: 3 groups" "3" "$GROUP_COUNT"

  # Output sorted by group ascending: A, B, C
  # Group A: sum=60, avg=20, count=3
  ROW_A=$(tail -n +2 "$DIR/out.csv" | head -1)
  A_GROUP=$(echo "$ROW_A" | cut -d',' -f1)
  A_SUM=$(echo "$ROW_A" | cut -d',' -f2)
  A_AVG=$(echo "$ROW_A" | cut -d',' -f3)
  A_CNT=$(echo "$ROW_A" | cut -d',' -f4)
  check "aggregate: group A sum=60" "60" "$A_SUM"
  check "aggregate: group A avg=20" "20" "$A_AVG"
  check "aggregate: group A count=3" "3" "$A_CNT"

  # Output sorted by group_by columns ascending
  FIRST_GROUP=$(tail -n +2 "$DIR/out.csv" | head -1 | cut -d',' -f1)
  check "aggregate: sorted ascending (first group is A)" "A" "$FIRST_GROUP"
else
  skip "aggregate: 3 groups"
  skip "aggregate: group A sum=60"
  skip "aggregate: group A avg=20"
  skip "aggregate: group A count=3"
  skip "aggregate: sorted ascending (first group is A)"
fi

# =============================================================================
# 15. Transform aggregate min/max
# =============================================================================
echo ""
echo "=== 15. Transform aggregate min/max ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_agg_minmax
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,group,value
1,X,10
2,X,30
3,X,20
4,Y,5
5,Y,
6,Y,15
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "aggregate", "group_by": ["group"], "aggregations": [
  {"column": "value", "function": "min", "as": "min_val"},
  {"column": "value", "function": "max", "as": "max_val"}
]}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # Group X: min=10, max=30
  ROW_X=$(tail -n +2 "$DIR/out.csv" | head -1)
  X_MIN=$(echo "$ROW_X" | cut -d',' -f2)
  X_MAX=$(echo "$ROW_X" | cut -d',' -f3)
  check "agg min/max: group X min=10" "10" "$X_MIN"
  check "agg min/max: group X max=30" "30" "$X_MAX"
else
  skip "agg min/max: group X min=10"
  skip "agg min/max: group X max=30"
fi

# =============================================================================
# 16. Transform join inner
# =============================================================================
echo ""
echo "=== 16. Transform join inner ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_join_inner
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name,score
1,Alice,80
2,Bob,90
3,Charlie,70
4,Diana,60
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,dept,city
1,Engineering,NYC
3,Marketing,LA
5,Sales,CHI
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "join", "right": "/tmp/test_join_inner/right.csv", "on": "id", "type": "inner"}]
EOF

  $DPIPE transform --input "$DIR/left.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # Inner join: only ids 1 and 3 match
  JOIN_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "inner join: row count is 2" "2" "$JOIN_COUNT"

  # Output columns: id,name,score,dept,city (right id excluded)
  HEADER=$(head -1 "$DIR/out.csv" 2>/dev/null)
  check_contains "inner join: has dept column" "dept" "$HEADER"
  check_contains "inner join: has city column" "city" "$HEADER"
else
  skip "inner join: row count is 2"
  skip "inner join: has dept column"
  skip "inner join: has city column"
fi

# =============================================================================
# 17. Transform join left
# =============================================================================
echo ""
echo "=== 17. Transform join left ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_join_left
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name,score
1,Alice,80
2,Bob,90
3,Charlie,70
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,dept
1,Engineering
3,Marketing
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "join", "right": "/tmp/test_join_left/right.csv", "on": "id", "type": "left"}]
EOF

  $DPIPE transform --input "$DIR/left.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # Left join: all 3 left rows present
  JOIN_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "left join: row count is 3" "3" "$JOIN_COUNT"

  # Row for id=2 has no match, dept should be empty
  # Preserve left order: id=1, id=2, id=3
  ROW_BOB=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  BOB_DEPT=$(echo "$ROW_BOB" | rev | cut -d',' -f1 | rev)
  check "left join: unmatched row has empty right column" "" "$BOB_DEPT"

  # Row for id=1 has match
  ROW_ALICE=$(tail -n +2 "$DIR/out.csv" | head -1)
  ALICE_DEPT=$(echo "$ROW_ALICE" | rev | cut -d',' -f1 | rev)
  check "left join: matched row has correct right value" "Engineering" "$ALICE_DEPT"
else
  skip "left join: row count is 3"
  skip "left join: unmatched row has empty right column"
  skip "left join: matched row has correct right value"
fi

# =============================================================================
# 18. Verify
# =============================================================================
echo ""
echo "=== 18. Verify ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_verify
  mkdir -p "$DIR"

  echo "hello world" > "$DIR/testfile.txt"
  sha256sum "$DIR/testfile.txt" | awk '{print $1}' > "$DIR/testfile.sha256"

  VERIFY_OUT=$($DPIPE verify --file "$DIR/testfile.txt" --checksum "$DIR/testfile.sha256" 2>&1)
  VERIFY_EXIT=$?
  check "verify match: prints VERIFIED" "0" "$VERIFY_EXIT"
  check_contains "verify match: stdout contains VERIFIED" "VERIFIED" "$VERIFY_OUT"

  echo "0000000000000000000000000000000000000000000000000000000000000000" > "$DIR/bad.sha256"
  MISMATCH_OUT=$($DPIPE verify --file "$DIR/testfile.txt" --checksum "$DIR/bad.sha256" 2>&1)
  MISMATCH_EXIT=$?
  # Exit code should be 1 on mismatch
  check "verify mismatch: exit code 1" "1" "$MISMATCH_EXIT"
  check_contains "verify mismatch: stdout contains MISMATCH" "MISMATCH" "$MISMATCH_OUT"
else
  skip "verify match: prints VERIFIED"
  skip "verify match: stdout contains VERIFIED"
  skip "verify mismatch: exit code 1"
  skip "verify mismatch: stdout contains MISMATCH"
fi

# =============================================================================
# 19. Manifest
# =============================================================================
echo ""
echo "=== 19. Manifest ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_manifest
  rm -rf "$DIR"
  mkdir -p "$DIR/subdir"

  cat > "$DIR/alpha.csv" << 'EOF'
id,val
1,10
2,20
EOF

  cat > "$DIR/subdir/beta.csv" << 'EOF'
x,y,z
a,b,c
d,e,f
e,f,g
EOF

  $DPIPE manifest --dir "$DIR" --output "$DIR/manifest.json" 2>/dev/null

  # Check JSON structure
  FILE_COUNT=$(python3 -c "import json; m=json.load(open('$DIR/manifest.json')); print(len(m['files']))" 2>/dev/null)
  check "manifest: file count is 2" "2" "$FILE_COUNT"

  HAS_GENERATED=$(python3 -c "import json; m=json.load(open('$DIR/manifest.json')); print('yes' if 'generated_at' in m else 'no')" 2>/dev/null)
  check "manifest: has generated_at field" "yes" "$HAS_GENERATED"
else
  skip "manifest: file count is 2"
  skip "manifest: has generated_at field"
fi

# =============================================================================
# 20. Pipeline success
# =============================================================================
echo ""
echo "=== 20. Pipeline success ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pipeline_ok
  mkdir -p "$DIR"

  cat > "$DIR/raw.csv" << 'EOF'
id,value,timestamp
3,30,2024-01-03T00:00:00Z
1,10,2024-01-01T00:00:00Z
2,20,2024-01-02T00:00:00Z
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "value", "type": "float", "required": true},
    {"name": "timestamp", "type": "datetime", "required": true}
  ],
  "primary_key": ["id"]
}
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "filter", "column": "value", "condition": "gt", "threshold": 5}]
EOF

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "ingest", "input": "/tmp/test_pipeline_ok/raw.csv", "schema": "/tmp/test_pipeline_ok/schema.json", "output": "/tmp/test_pipeline_ok/clean.csv"},
    {"type": "transform", "input": "/tmp/test_pipeline_ok/clean.csv", "recipe": "/tmp/test_pipeline_ok/recipe.json", "output": "/tmp/test_pipeline_ok/final.csv"},
    {"type": "verify", "file": "/tmp/test_pipeline_ok/final.csv", "checksum": "/tmp/test_pipeline_ok/final.csv.sha256"}
  ]
}
EOF

  PIPE_OUT=$($DPIPE pipeline --config "$DIR/pipeline.json" 2>&1)
  PIPE_EXIT=$?
  check "pipeline success: exit code 0" "0" "$PIPE_EXIT"
  check_contains "pipeline success: PIPELINE OK message" "PIPELINE OK" "$PIPE_OUT"
else
  skip "pipeline success: exit code 0"
  skip "pipeline success: PIPELINE OK message"
fi

# =============================================================================
# 21. Pipeline failure
# =============================================================================
echo ""
echo "=== 21. Pipeline failure ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pipeline_fail
  mkdir -p "$DIR"

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "ingest", "input": "/tmp/does_not_exist.csv", "schema": "/tmp/test_pipeline_fail/schema.json", "output": "/tmp/test_pipeline_fail/out.csv"}
  ]
}
EOF

  # Schema file needed for the pipeline to even parse (but input doesn't exist)
  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [{"name": "id", "type": "int", "required": true}],
  "primary_key": ["id"]
}
EOF

  FAIL_OUT=$($DPIPE pipeline --config "$DIR/pipeline.json" 2>&1)
  FAIL_EXIT=$?
  check "pipeline failure: exit code 1" "1" "$FAIL_EXIT"
  check_contains "pipeline failure: PIPELINE FAILED message" "PIPELINE FAILED" "$FAIL_OUT"
else
  skip "pipeline failure: exit code 1"
  skip "pipeline failure: PIPELINE FAILED message"
fi

# =============================================================================
# 22. Determinism
# =============================================================================
echo ""
echo "=== 22. Determinism ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_determinism
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,20
3,30
4,40
5,50
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[
  {"op": "filter", "column": "value", "condition": "gte", "threshold": 20},
  {"op": "derive", "name": "doubled", "expression": "value * 2"},
  {"op": "sort", "column": "doubled", "order": "desc"}
]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/run1.csv" --seed 42 2>/dev/null
  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/run2.csv" --seed 42 2>/dev/null

  SHA_R1=$(sha256sum "$DIR/run1.csv" 2>/dev/null | awk '{print $1}')
  SHA_R2=$(sha256sum "$DIR/run2.csv" 2>/dev/null | awk '{print $1}')
  check "determinism: two identical runs produce same SHA-256" "$SHA_R1" "$SHA_R2"

  # Also check .sha256 files match
  STORED_R1=$(tr -d '[:space:]' < "$DIR/run1.csv.sha256" 2>/dev/null)
  STORED_R2=$(tr -d '[:space:]' < "$DIR/run2.csv.sha256" 2>/dev/null)
  check "determinism: stored SHA-256 files match" "$STORED_R1" "$STORED_R2"
else
  skip "determinism: two identical runs produce same SHA-256"
  skip "determinism: stored SHA-256 files match"
fi

# =============================================================================
# 23. Error handling
# =============================================================================
echo ""
echo "=== 23. Error handling ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_errors
  mkdir -p "$DIR"

  # Missing input file
  ERR_FILE=$($DPIPE ingest --input /tmp/nonexistent_file_xyz.csv --schema "$DIR/dummy.json" --output "$DIR/out.csv" 2>&1)
  ERR_FILE_EXIT=$?
  check "error: missing file exit code 1" "1" "$ERR_FILE_EXIT"
  check_contains "error: missing file message" "file not found" "$ERR_FILE"

  # Unknown transform op
  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
EOF
  cat > "$DIR/bad_op.json" << 'EOF'
[{"op": "nonexistent_operation", "column": "value"}]
EOF
  ERR_OP=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/bad_op.json" --output "$DIR/out.csv" --seed 42 2>&1)
  ERR_OP_EXIT=$?
  check "error: unknown op exit code 1" "1" "$ERR_OP_EXIT"
  check_contains "error: unknown op message" "invalid recipe" "$ERR_OP"

  # Malformed JSON
  echo "this is not json{{{" > "$DIR/bad.json"
  ERR_JSON=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/bad.json" --output "$DIR/out.csv" --seed 42 2>&1)
  ERR_JSON_EXIT=$?
  check "error: malformed JSON exit code 1" "1" "$ERR_JSON_EXIT"
  check_contains "error: malformed JSON message" "malformed JSON" "$ERR_JSON"

  # Invalid regex pattern in schema
  cat > "$DIR/bad_pattern_schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "code", "type": "string", "required": true, "pattern": "[invalid("}
  ],
  "primary_key": ["id"]
}
EOF
  cat > "$DIR/pattern_data.csv" << 'EOF'
id,code
1,abc
EOF
  ERR_PAT=$($DPIPE ingest --input "$DIR/pattern_data.csv" --schema "$DIR/bad_pattern_schema.json" --output "$DIR/out.csv" 2>&1)
  ERR_PAT_EXIT=$?
  check "error: invalid pattern exit code 1" "1" "$ERR_PAT_EXIT"
  check_contains "error: invalid pattern message" "invalid pattern" "$ERR_PAT"
else
  skip "error: missing file exit code 1"
  skip "error: missing file message"
  skip "error: unknown op exit code 1"
  skip "error: unknown op message"
  skip "error: malformed JSON exit code 1"
  skip "error: malformed JSON message"
  skip "error: invalid pattern exit code 1"
  skip "error: invalid pattern message"
fi

# =============================================================================
# 24. Division by zero
# =============================================================================
echo ""
echo "=== 24. Division by zero ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_divzero
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value,zero
1,10,0
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "value / zero"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null
  DIV_VAL=$(tail -n +2 "$DIR/out.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "divzero: value/0 = NaN" "NaN" "$DIV_VAL"
else
  skip "divzero: value/0 = NaN"
fi

# =============================================================================
# 25. Modulo
# =============================================================================
echo ""
echo "=== 25. Modulo ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_modulo
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,7
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "value % 3"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null
  MOD_VAL=$(tail -n +2 "$DIR/out.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "modulo: 7 %% 3 = 1" "1" "$MOD_VAL"
else
  skip "modulo: 7 %% 3 = 1"
fi

# =============================================================================
# 26. Parentheses
# =============================================================================
echo ""
echo "=== 26. Parentheses ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_parens
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,a,b,c
1,2,3,4
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "(a + b) * c"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null
  PAREN_VAL=$(tail -n +2 "$DIR/out.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "parens: (2+3)*4 = 20" "20" "$PAREN_VAL"
else
  skip "parens: (2+3)*4 = 20"
fi

# =============================================================================
# 27. Join key missing error
# =============================================================================
echo ""
echo "=== 27. Join key missing error ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_join_err
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name
1,Alice
2,Bob
EOF

  cat > "$DIR/right.csv" << 'EOF'
code,dept
X,Engineering
Y,Marketing
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "join", "right": "/tmp/test_join_err/right.csv", "on": "id", "type": "inner"}]
EOF

  JOIN_ERR=$($DPIPE transform --input "$DIR/left.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>&1)
  JOIN_ERR_EXIT=$?
  check "join key error: exit code 1" "1" "$JOIN_ERR_EXIT"
  check_contains "join key error: message mentions key not found" "not found" "$JOIN_ERR"
else
  skip "join key error: exit code 1"
  skip "join key error: message mentions key not found"
fi

# =============================================================================
# 28. Additional filter conditions (lte, neq)
# =============================================================================
echo ""
echo "=== 28. Additional filter conditions ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_filter_extra
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,5
2,10
3,15
4,20
5,25
EOF

  # lte 15 => rows 1,2,3
  cat > "$DIR/recipe_lte.json" << 'EOF'
[{"op": "filter", "column": "value", "condition": "lte", "threshold": 15}]
EOF
  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe_lte.json" --output "$DIR/out_lte.csv" --seed 42 2>/dev/null
  LTE_COUNT=$(tail -n +2 "$DIR/out_lte.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "filter lte 15: row count is 3" "3" "$LTE_COUNT"

  # neq 10 => rows 1,3,4,5
  cat > "$DIR/recipe_neq.json" << 'EOF'
[{"op": "filter", "column": "value", "condition": "neq", "threshold": 10}]
EOF
  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe_neq.json" --output "$DIR/out_neq.csv" --seed 42 2>/dev/null
  NEQ_COUNT=$(tail -n +2 "$DIR/out_neq.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "filter neq 10: row count is 4" "4" "$NEQ_COUNT"

  # eq 10 => row 2 only
  cat > "$DIR/recipe_eq.json" << 'EOF'
[{"op": "filter", "column": "value", "condition": "eq", "threshold": 10}]
EOF
  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe_eq.json" --output "$DIR/out_eq.csv" --seed 42 2>/dev/null
  EQ_COUNT=$(tail -n +2 "$DIR/out_eq.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "filter eq 10: row count is 1" "1" "$EQ_COUNT"
else
  skip "filter lte 15: row count is 3"
  skip "filter neq 10: row count is 4"
  skip "filter eq 10: row count is 1"
fi

# =============================================================================
# 29. Rename and drop
# =============================================================================
echo ""
echo "=== 29. Rename and drop ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_rename_drop
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value,label,extra
1,10,A,x
2,20,B,y
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[
  {"op": "rename", "from": "label", "to": "category"},
  {"op": "drop", "columns": ["extra"]}
]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  OUT_HEADER=$(head -1 "$DIR/out.csv" 2>/dev/null)
  check_contains "rename: header has category" "category" "$OUT_HEADER"

  # Should NOT contain label or extra
  HAS_LABEL="no"
  if echo "$OUT_HEADER" | grep -qF "label"; then HAS_LABEL="yes"; fi
  check "rename: header does not have label" "no" "$HAS_LABEL"

  HAS_EXTRA="no"
  if echo "$OUT_HEADER" | grep -qF "extra"; then HAS_EXTRA="yes"; fi
  check "drop: header does not have extra" "no" "$HAS_EXTRA"
else
  skip "rename: header has category"
  skip "rename: header does not have label"
  skip "drop: header does not have extra"
fi

# =============================================================================
# 30. Chained transform pipeline
# =============================================================================
echo ""
echo "=== 30. Chained transform pipeline ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_chain
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value,label
1,5,alpha
2,15,beta
3,25,gamma
4,10,delta
5,35,epsilon
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[
  {"op": "filter", "column": "value", "condition": "gte", "threshold": 10},
  {"op": "derive", "name": "doubled", "expression": "value * 2"},
  {"op": "sort", "column": "doubled", "order": "asc"}
]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  CHAIN_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "chain: filter gte 10 keeps 4 rows" "4" "$CHAIN_COUNT"

  # Sorted asc by doubled: 10*2=20, 15*2=30, 25*2=50, 35*2=70
  FIRST_DOUBLED=$(tail -n +2 "$DIR/out.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "chain: first doubled value is 20" "20" "$FIRST_DOUBLED"

  LAST_DOUBLED=$(tail -n +2 "$DIR/out.csv" | tail -1 | rev | cut -d',' -f1 | rev)
  check "chain: last doubled value is 70" "70" "$LAST_DOUBLED"
else
  skip "chain: filter gte 10 keeps 4 rows"
  skip "chain: first doubled value is 20"
  skip "chain: last doubled value is 70"
fi

# =============================================================================
# 31. Ingest with all valid rows (no rejected file should exist or be empty)
# =============================================================================
echo ""
echo "=== 31. Ingest all valid ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_all_valid
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,10
2,20
3,30
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "value", "type": "float", "required": true}
  ],
  "primary_key": ["id"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  VALID_COUNT=$(tail -n +2 "$DIR/output.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "all valid: row count is 3" "3" "$VALID_COUNT"
else
  skip "all valid: row count is 3"
fi

# =============================================================================
# 32. Manifest row count and size_bytes
# =============================================================================
echo ""
echo "=== 32. Manifest row count and size ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_manifest_detail
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,val
1,10
2,20
3,30
EOF

  $DPIPE manifest --dir "$DIR" --output "$DIR/manifest.json" 2>/dev/null

  M_ROWS=$(python3 -c "import json; m=json.load(open('$DIR/manifest.json')); print(m['files'][0]['rows'])" 2>/dev/null)
  check "manifest detail: rows count is 3" "3" "$M_ROWS"

  # Check size_bytes matches actual file size
  ACTUAL_SIZE=$(wc -c < "$DIR/data.csv" | tr -d ' ')
  M_SIZE=$(python3 -c "import json; m=json.load(open('$DIR/manifest.json')); print(m['files'][0]['size_bytes'])" 2>/dev/null)
  check "manifest detail: size_bytes matches" "$ACTUAL_SIZE" "$M_SIZE"

  # Check SHA in manifest matches computed
  ACTUAL_SHA=$(sha256sum "$DIR/data.csv" | awk '{print $1}')
  M_SHA=$(python3 -c "import json; m=json.load(open('$DIR/manifest.json')); print(m['files'][0]['sha256'])" 2>/dev/null)
  check "manifest detail: SHA-256 matches" "$ACTUAL_SHA" "$M_SHA"
else
  skip "manifest detail: rows count is 3"
  skip "manifest detail: size_bytes matches"
  skip "manifest detail: SHA-256 matches"
fi

# =============================================================================
# 33. Manifest sorted by path
# =============================================================================
echo ""
echo "=== 33. Manifest sorted by path ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_manifest_sort
  rm -rf "$DIR"
  mkdir -p "$DIR/sub"

  cat > "$DIR/z.csv" << 'EOF'
id
1
EOF
  cat > "$DIR/a.csv" << 'EOF'
id
1
EOF
  cat > "$DIR/sub/m.csv" << 'EOF'
id
1
EOF

  $DPIPE manifest --dir "$DIR" --output "$DIR/manifest.json" 2>/dev/null

  FIRST_PATH=$(python3 -c "import json; m=json.load(open('$DIR/manifest.json')); print(m['files'][0]['path'])" 2>/dev/null)
  check "manifest sort: first file is a.csv" "a.csv" "$FIRST_PATH"
else
  skip "manifest sort: first file is a.csv"
fi

# =============================================================================
# 34. Ingest: required field empty rejects row
# =============================================================================
echo ""
echo "=== 34. Ingest required field empty ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_required_empty
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,10
2,
3,30
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "value", "type": "float", "required": true}
  ],
  "primary_key": ["id"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  VALID_COUNT=$(tail -n +2 "$DIR/output.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "required empty: valid row count is 2" "2" "$VALID_COUNT"
else
  skip "required empty: valid row count is 2"
fi

# =============================================================================
# 35. Ingest: optional field empty is accepted
# =============================================================================
echo ""
echo "=== 35. Ingest optional field empty ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_optional_empty
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value,label
1,10,
2,20,hello
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "value", "type": "float", "required": true},
    {"name": "label", "type": "string", "required": false}
  ],
  "primary_key": ["id"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  VALID_COUNT=$(tail -n +2 "$DIR/output.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "optional empty: valid row count is 2" "2" "$VALID_COUNT"
else
  skip "optional empty: valid row count is 2"
fi

# =============================================================================
# 36. Verify: MISMATCH output format
# =============================================================================
echo ""
echo "=== 36. Verify MISMATCH format ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_verify_format
  mkdir -p "$DIR"

  echo "test content" > "$DIR/file.txt"
  echo "aaaa" > "$DIR/bad.sha256"

  MISMATCH_OUT=$($DPIPE verify --file "$DIR/file.txt" --checksum "$DIR/bad.sha256" 2>&1)
  # Should contain expected= and actual=
  check_contains "verify mismatch format: contains expected=" "expected=" "$MISMATCH_OUT"
  check_contains "verify mismatch format: contains actual=" "actual=" "$MISMATCH_OUT"
else
  skip "verify mismatch format: contains expected="
  skip "verify mismatch format: contains actual="
fi

# =============================================================================
# 37. Pipeline: step count in success message
# =============================================================================
echo ""
echo "=== 37. Pipeline step count ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pipeline_count
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,10
2,20
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "value", "type": "float", "required": true}
  ],
  "primary_key": ["id"]
}
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "sort", "column": "value", "order": "asc"}]
EOF

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "ingest", "input": "/tmp/test_pipeline_count/data.csv", "schema": "/tmp/test_pipeline_count/schema.json", "output": "/tmp/test_pipeline_count/clean.csv"},
    {"type": "transform", "input": "/tmp/test_pipeline_count/clean.csv", "recipe": "/tmp/test_pipeline_count/recipe.json", "output": "/tmp/test_pipeline_count/final.csv"}
  ]
}
EOF

  PIPE_OUT=$($DPIPE pipeline --config "$DIR/pipeline.json" 2>&1)
  check_contains "pipeline step count: mentions 2 steps" "2 steps completed" "$PIPE_OUT"
else
  skip "pipeline step count: mentions 2 steps"
fi

# =============================================================================
# 38. Pipeline failure at step 2
# =============================================================================
echo ""
echo "=== 38. Pipeline failure at step 2 ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pipeline_fail2
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,10
2,20
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "value", "type": "float", "required": true}
  ],
  "primary_key": ["id"]
}
EOF

  cat > "$DIR/bad_recipe.json" << 'EOF'
[{"op": "wobble"}]
EOF

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "ingest", "input": "/tmp/test_pipeline_fail2/data.csv", "schema": "/tmp/test_pipeline_fail2/schema.json", "output": "/tmp/test_pipeline_fail2/clean.csv"},
    {"type": "transform", "input": "/tmp/test_pipeline_fail2/clean.csv", "recipe": "/tmp/test_pipeline_fail2/bad_recipe.json", "output": "/tmp/test_pipeline_fail2/final.csv"}
  ]
}
EOF

  FAIL2_OUT=$($DPIPE pipeline --config "$DIR/pipeline.json" 2>&1)
  FAIL2_EXIT=$?
  check "pipeline fail step 2: exit code 1" "1" "$FAIL2_EXIT"
  check_contains "pipeline fail step 2: PIPELINE FAILED at step 2" "PIPELINE FAILED at step 2" "$FAIL2_OUT"
else
  skip "pipeline fail step 2: exit code 1"
  skip "pipeline fail step 2: PIPELINE FAILED at step 2"
fi

# =============================================================================
# 39. Aggregate: count, sum with different data
# =============================================================================
echo ""
echo "=== 39. Aggregate with multiple groups ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_agg2
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,cat,amount
1,food,10
2,food,20
3,transport,30
4,food,5
5,transport,15
6,other,100
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "aggregate", "group_by": ["cat"], "aggregations": [
  {"column": "amount", "function": "sum", "as": "total"},
  {"column": "id", "function": "count", "as": "n"}
]}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  GROUP_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "agg multi: 3 groups" "3" "$GROUP_COUNT"

  # food: sum=35, count=3; output sorted: food, other, transport
  FIRST_ROW=$(tail -n +2 "$DIR/out.csv" | head -1)
  FIRST_CAT=$(echo "$FIRST_ROW" | cut -d',' -f1)
  FIRST_TOTAL=$(echo "$FIRST_ROW" | cut -d',' -f2)
  check "agg multi: first group is food" "food" "$FIRST_CAT"
  check "agg multi: food total=35" "35" "$FIRST_TOTAL"
else
  skip "agg multi: 3 groups"
  skip "agg multi: first group is food"
  skip "agg multi: food total=35"
fi

# =============================================================================
# 40. Aggregate: avg with NaN when no values
# =============================================================================
echo ""
echo "=== 40. Aggregate avg edge case ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_agg_avg
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,group,value
1,A,10
2,A,20
3,B,
4,B,
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "aggregate", "group_by": ["group"], "aggregations": [
  {"column": "value", "function": "avg", "as": "mean"}
]}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # Group A: avg=15; Group B: avg=NaN (no numeric values)
  ROW_A=$(tail -n +2 "$DIR/out.csv" | head -1)
  A_MEAN=$(echo "$ROW_A" | cut -d',' -f2)
  check "agg avg: group A mean=15" "15" "$A_MEAN"

  ROW_B=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  B_MEAN=$(echo "$ROW_B" | cut -d',' -f2)
  check "agg avg: group B mean=NaN (no numeric values)" "NaN" "$B_MEAN"
else
  skip "agg avg: group A mean=15"
  skip "agg avg: group B mean=NaN (no numeric values)"
fi

# =============================================================================
# 41. Join preserves left order
# =============================================================================
echo ""
echo "=== 41. Join preserves left order ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_join_order
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name
3,Charlie
1,Alice
2,Bob
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,dept
1,Engineering
2,Marketing
3,Sales
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "join", "right": "/tmp/test_join_order/right.csv", "on": "id", "type": "inner"}]
EOF

  $DPIPE transform --input "$DIR/left.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # Left order: 3, 1, 2
  FIRST_NAME=$(tail -n +2 "$DIR/out.csv" | head -1 | cut -d',' -f2)
  check "join order: first row is Charlie (preserves left order)" "Charlie" "$FIRST_NAME"
else
  skip "join order: first row is Charlie (preserves left order)"
fi

# =============================================================================
# 42. Join: only first right match used for duplicate keys
# =============================================================================
echo ""
echo "=== 42. Join dedup right ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_join_dedup
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name
1,Alice
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,dept
1,Engineering
1,Marketing
1,Sales
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "join", "right": "/tmp/test_join_dedup/right.csv", "on": "id", "type": "inner"}]
EOF

  $DPIPE transform --input "$DIR/left.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  JOIN_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "join dedup: only 1 output row" "1" "$JOIN_COUNT"

  # Should use the first match: Engineering
  DEPT=$(tail -n +2 "$DIR/out.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "join dedup: uses first right match (Engineering)" "Engineering" "$DEPT"
else
  skip "join dedup: only 1 output row"
  skip "join dedup: uses first right match (Engineering)"
fi

# =============================================================================
# 43. Ingest: datetime validation
# =============================================================================
echo ""
echo "=== 43. Ingest datetime validation ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_datetime
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,ts
1,2024-01-01T00:00:00Z
2,2024-13-01T00:00:00Z
3,2024-06-15T12:30:00Z
4,not-a-date
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "ts", "type": "datetime", "required": true}
  ],
  "primary_key": ["id"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  # Rows 2 and 4 have invalid dates
  VALID_COUNT=$(tail -n +2 "$DIR/output.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "datetime: valid row count is 2" "2" "$VALID_COUNT"
else
  skip "datetime: valid row count is 2"
fi

# =============================================================================
# 44. Ingest: int type rejects floats
# =============================================================================
echo ""
echo "=== 44. Ingest int type validation ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_int_type
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,count
1,10
2,3.14
3,20
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "count", "type": "int", "required": true}
  ],
  "primary_key": ["id"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  # Row 2 has float 3.14 for int column, should be rejected
  VALID_COUNT=$(tail -n +2 "$DIR/output.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "int type: 3.14 rejected for int column, valid count is 2" "2" "$VALID_COUNT"
else
  skip "int type: 3.14 rejected for int column, valid count is 2"
fi

# =============================================================================
# 45. SHA-256 checksum written after transform
# =============================================================================
echo ""
echo "=== 45. Transform SHA-256 ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_transform_sha
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,20
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "sort", "column": "value", "order": "asc"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  if [ -f "$DIR/out.csv.sha256" ]; then
    COMPUTED=$(sha256sum "$DIR/out.csv" | awk '{print $1}')
    STORED=$(tr -d '[:space:]' < "$DIR/out.csv.sha256")
    check "transform SHA: checksum matches" "$COMPUTED" "$STORED"
  else
    check "transform SHA: .sha256 file exists" "1" "0"
  fi
else
  skip "transform SHA: checksum matches"
fi

# =============================================================================
# 46. Ingest: validation order (required/type before range before pattern)
# =============================================================================
echo ""
echo "=== 46. Validation order ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_val_order
  mkdir -p "$DIR"

  # A row that fails both type check AND would fail range check
  # Should report the type error, not the range error
  cat > "$DIR/data.csv" << 'EOF'
id,value
1,abc
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "value", "type": "float", "required": true, "min": 0, "max": 100}
  ],
  "primary_key": ["id"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  VALID_COUNT=$(tail -n +2 "$DIR/output.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "validation order: type-invalid row rejected" "0" "$VALID_COUNT"
else
  skip "validation order: type-invalid row rejected"
fi

# =============================================================================
# 47. Aggregate formatting: no trailing zeros
# =============================================================================
echo ""
echo "=== 47. Aggregate formatting ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_agg_format
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,group,value
1,A,10
2,A,20
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "aggregate", "group_by": ["group"], "aggregations": [
  {"column": "value", "function": "sum", "as": "total"},
  {"column": "value", "function": "avg", "as": "mean"}
]}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # sum=30 (should be "30" not "30.0"), avg=15 (should be "15" not "15.0")
  ROW=$(tail -n +2 "$DIR/out.csv" | head -1)
  SUM_VAL=$(echo "$ROW" | cut -d',' -f2)
  AVG_VAL=$(echo "$ROW" | cut -d',' -f3)
  check "agg format: sum 30 not 30.0" "30" "$SUM_VAL"
  check "agg format: avg 15 not 15.0" "15" "$AVG_VAL"
else
  skip "agg format: sum 30 not 30.0"
  skip "agg format: avg 15 not 15.0"
fi

# =============================================================================
# 48. Aggregate with non-integer average
# =============================================================================
echo ""
echo "=== 48. Aggregate non-integer avg ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_agg_nonint
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,group,value
1,A,10
2,A,20
3,A,30
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "aggregate", "group_by": ["group"], "aggregations": [
  {"column": "value", "function": "avg", "as": "mean"}
]}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # avg = 60/3 = 20 (clean integer)
  ROW=$(tail -n +2 "$DIR/out.csv" | head -1)
  MEAN=$(echo "$ROW" | cut -d',' -f2)
  check "agg nonint: avg of 10,20,30 = 20" "20" "$MEAN"
else
  skip "agg nonint: avg of 10,20,30 = 20"
fi

# =============================================================================
# 49. Derive: subtraction
# =============================================================================
echo ""
echo "=== 49. Derive subtraction ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_derive_sub
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,a,b
1,10,3
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "a - b"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null
  SUB_VAL=$(tail -n +2 "$DIR/out.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "derive sub: 10 - 3 = 7" "7" "$SUB_VAL"
else
  skip "derive sub: 10 - 3 = 7"
fi

# =============================================================================
# 50. Derive: literal numbers in expression
# =============================================================================
echo ""
echo "=== 50. Derive with literal numbers ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_derive_literal
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "value + 100"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null
  LIT_VAL=$(tail -n +2 "$DIR/out.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "derive literal: 10 + 100 = 110" "110" "$LIT_VAL"
else
  skip "derive literal: 10 + 100 = 110"
fi

# =============================================================================
# 51. Ingest: rejected file has rejection_reason column
# =============================================================================
echo ""
echo "=== 51. Rejected file format ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_reject_format
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,10
2,abc
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "value", "type": "float", "required": true}
  ],
  "primary_key": ["id"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  if [ -f "$DIR/output.csv.rejected" ]; then
    REJ_HEADER=$(head -1 "$DIR/output.csv.rejected")
    check_contains "rejected format: has rejection_reason column" "rejection_reason" "$REJ_HEADER"
  else
    check "rejected format: rejected file exists" "1" "0"
  fi
else
  skip "rejected format: has rejection_reason column"
fi

# =============================================================================
# 52. Filter: nonexistent column => error
# =============================================================================
echo ""
echo "=== 52. Filter nonexistent column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_filter_err
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "filter", "column": "nonexistent", "condition": "gt", "threshold": 5}]
EOF

  FILTER_ERR=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>&1)
  FILTER_ERR_EXIT=$?
  check "filter nonexistent col: exit code 1" "1" "$FILTER_ERR_EXIT"
  check_contains "filter nonexistent col: invalid recipe message" "invalid recipe" "$FILTER_ERR"
else
  skip "filter nonexistent col: exit code 1"
  skip "filter nonexistent col: invalid recipe message"
fi

# =============================================================================
# 53. Sort: nonexistent column => error
# =============================================================================
echo ""
echo "=== 53. Sort nonexistent column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_sort_err
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "sort", "column": "missing", "order": "asc"}]
EOF

  SORT_ERR=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>&1)
  SORT_ERR_EXIT=$?
  check "sort nonexistent col: exit code 1" "1" "$SORT_ERR_EXIT"
  check_contains "sort nonexistent col: invalid recipe message" "invalid recipe" "$SORT_ERR"
else
  skip "sort nonexistent col: exit code 1"
  skip "sort nonexistent col: invalid recipe message"
fi

# =============================================================================
# 54. Ingest: primary key sort with datetime
# =============================================================================
echo ""
echo "=== 54. Primary key sort datetime ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pk_datetime
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
ts,value
2024-06-15T00:00:00Z,30
2024-01-01T00:00:00Z,10
2024-03-10T00:00:00Z,20
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "ts", "type": "datetime", "required": true},
    {"name": "value", "type": "float", "required": true}
  ],
  "primary_key": ["ts"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  FIRST_TS=$(tail -n +2 "$DIR/output.csv" | head -1 | cut -d',' -f1)
  check "pk datetime: first row is earliest date" "2024-01-01T00:00:00Z" "$FIRST_TS"
else
  skip "pk datetime: first row is earliest date"
fi

# =============================================================================
# 55. Transform: multiple derives in sequence
# =============================================================================
echo ""
echo "=== 55. Multiple derives ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_multi_derive
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,x
1,5
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[
  {"op": "derive", "name": "doubled", "expression": "x * 2"},
  {"op": "derive", "name": "tripled", "expression": "doubled + x"}
]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv" 2>/dev/null)
  check_contains "multi derive: has doubled column" "doubled" "$HEADER"
  check_contains "multi derive: has tripled column" "tripled" "$HEADER"

  # doubled=10, tripled=10+5=15
  TRIPLED=$(tail -n +2 "$DIR/out.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "multi derive: tripled = doubled + x = 15" "15" "$TRIPLED"
else
  skip "multi derive: has doubled column"
  skip "multi derive: has tripled column"
  skip "multi derive: tripled = doubled + x = 15"
fi

# =============================================================================
# 56. Ingest: min/max on float column
# =============================================================================
echo ""
echo "=== 56. Min/max on float column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_minmax_float
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,temp
1,0.5
2,-0.1
3,99.9
4,100.1
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": [
    {"name": "id", "type": "int", "required": true},
    {"name": "temp", "type": "float", "required": true, "min": 0, "max": 100}
  ],
  "primary_key": ["id"]
}
EOF

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  # -0.1 and 100.1 out of range
  VALID_COUNT=$(tail -n +2 "$DIR/output.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "minmax float: valid count is 2" "2" "$VALID_COUNT"
else
  skip "minmax float: valid count is 2"
fi

# =============================================================================
# 57. Window rank
# =============================================================================
echo ""
echo "=== 57. Window rank ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_window_rank
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,cat,value
1,A,30
2,A,20
3,A,30
4,B,10
5,B,40
6,B,40
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "window", "function": "rank", "partition_by": ["cat"], "order_by": [{"column": "value", "order": "desc"}], "as": "rnk"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  ROW_COUNT=$(tail -n +2 "$DIR/output.csv" | wc -l | tr -d ' ')
  check "window rank: row count is 6" "6" "$ROW_COUNT"

  HEADER=$(head -1 "$DIR/output.csv")
  check_contains "window rank: header contains rnk" "rnk" "$HEADER"

  # Row 1 (line 2): id=1,cat=A,value=30,rnk=1
  ROW_1=$(sed -n '2p' "$DIR/output.csv")
  check "window rank: row 1 is id=1,A,30,rnk=1" "1,A,30,1" "$ROW_1"

  # Row 2 (line 3): id=2,cat=A,value=20,rnk=3
  ROW_2=$(sed -n '3p' "$DIR/output.csv")
  check "window rank: row 2 is id=2,A,20,rnk=3" "2,A,20,3" "$ROW_2"
else
  skip "window rank: row count is 6"
  skip "window rank: header contains rnk"
  skip "window rank: row 1 is id=1,A,30,rnk=1"
  skip "window rank: row 2 is id=2,A,20,rnk=3"
fi

# =============================================================================
# 58. Window dense_rank
# =============================================================================
echo ""
echo "=== 58. Window dense_rank ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_window_dense_rank
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,cat,value
1,A,30
2,A,20
3,A,30
4,B,10
5,B,40
6,B,40
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "window", "function": "dense_rank", "partition_by": ["cat"], "order_by": [{"column": "value", "order": "desc"}], "as": "drnk"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  # Row 2 (line 3): id=2,cat=A,value=20,drnk=2
  ROW_2=$(sed -n '3p' "$DIR/output.csv")
  check "window dense_rank: row 2 drnk=2" "2,A,20,2" "$ROW_2"

  # Row 4 (line 5): id=4,cat=B,value=10,drnk=2
  ROW_4=$(sed -n '5p' "$DIR/output.csv")
  check "window dense_rank: row 4 drnk=2" "4,B,10,2" "$ROW_4"
else
  skip "window dense_rank: row 2 drnk=2"
  skip "window dense_rank: row 4 drnk=2"
fi

# =============================================================================
# 59. Window row_number
# =============================================================================
echo ""
echo "=== 59. Window row_number ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_window_row_number
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,cat,value
1,A,30
2,A,20
3,A,30
4,B,10
5,B,40
6,B,40
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "window", "function": "row_number", "partition_by": ["cat"], "order_by": [{"column": "value", "order": "desc"}], "as": "rn"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  # Row 2 (line 3): id=2,cat=A,value=20,rn=3
  ROW_2=$(sed -n '3p' "$DIR/output.csv")
  check "window row_number: row 2 rn=3" "2,A,20,3" "$ROW_2"

  # Row 3 (line 4): id=3,cat=A,value=30,rn=2
  ROW_3=$(sed -n '4p' "$DIR/output.csv")
  check "window row_number: row 3 rn=2" "3,A,30,2" "$ROW_3"
else
  skip "window row_number: row 2 rn=3"
  skip "window row_number: row 3 rn=2"
fi

# =============================================================================
# 60. Window lag
# =============================================================================
echo ""
echo "=== 60. Window lag ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_window_lag
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,cat,value
1,A,30
2,A,20
3,A,30
4,B,10
5,B,40
6,B,40
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "window", "function": "lag", "source_column": "value", "offset": 1, "default": "0", "partition_by": ["cat"], "order_by": [{"column": "id", "order": "asc"}], "as": "prev_val"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  # Row 2 (line 3): id=2,cat=A,value=20,prev_val=30
  ROW_2=$(sed -n '3p' "$DIR/output.csv")
  check "window lag: row 2 prev_val=30" "2,A,20,30" "$ROW_2"

  # Row 5 (line 6): id=5,cat=B,value=40,prev_val=10
  ROW_5=$(sed -n '6p' "$DIR/output.csv")
  check "window lag: row 5 prev_val=10" "5,B,40,10" "$ROW_5"
else
  skip "window lag: row 2 prev_val=30"
  skip "window lag: row 5 prev_val=10"
fi

# =============================================================================
# 61. Window lead
# =============================================================================
echo ""
echo "=== 61. Window lead ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_window_lead
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,cat,value
1,A,30
2,A,20
3,A,30
4,B,10
5,B,40
6,B,40
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "window", "function": "lead", "source_column": "value", "offset": 1, "default": "-1", "partition_by": ["cat"], "order_by": [{"column": "id", "order": "asc"}], "as": "next_val"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  # Row 1 (line 2): id=1,cat=A,value=30,next_val=20
  ROW_1=$(sed -n '2p' "$DIR/output.csv")
  check "window lead: row 1 next_val=20" "1,A,30,20" "$ROW_1"

  # Row 3 (line 4): id=3,cat=A,value=30,next_val=-1
  ROW_3=$(sed -n '4p' "$DIR/output.csv")
  check "window lead: row 3 next_val=-1" "3,A,30,-1" "$ROW_3"

  # Row 6 (line 7): id=6,cat=B,value=40,next_val=-1
  ROW_6=$(sed -n '7p' "$DIR/output.csv")
  check "window lead: row 6 next_val=-1" "6,B,40,-1" "$ROW_6"
else
  skip "window lead: row 1 next_val=20"
  skip "window lead: row 3 next_val=-1"
  skip "window lead: row 6 next_val=-1"
fi

# =============================================================================
# 62. Window running_sum
# =============================================================================
echo ""
echo "=== 62. Window running_sum ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_window_running_sum
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,cat,value
1,A,30
2,A,20
3,A,30
4,B,10
5,B,40
6,B,40
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "window", "function": "running_sum", "source_column": "value", "partition_by": ["cat"], "order_by": [{"column": "id", "order": "asc"}], "as": "cum_val"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  # Row 2 (line 3): id=2,cat=A,value=20,cum_val=50
  ROW_2=$(sed -n '3p' "$DIR/output.csv")
  check "window running_sum: row 2 cum_val=50" "2,A,20,50" "$ROW_2"

  # Row 5 (line 6): id=5,cat=B,value=40,cum_val=50
  ROW_5=$(sed -n '6p' "$DIR/output.csv")
  check "window running_sum: row 5 cum_val=50" "5,B,40,50" "$ROW_5"
else
  skip "window running_sum: row 2 cum_val=50"
  skip "window running_sum: row 5 cum_val=50"
fi

# =============================================================================
# 63. Window running_avg
# =============================================================================
echo ""
echo "=== 63. Window running_avg ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_window_running_avg
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,cat,value
1,A,30
2,A,20
3,A,30
4,B,10
5,B,40
6,B,40
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "window", "function": "running_avg", "source_column": "value", "partition_by": ["cat"], "order_by": [{"column": "id", "order": "asc"}], "as": "avg_val"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  # Row 2 (line 3): id=2,cat=A,value=20,avg_val=25
  ROW_2=$(sed -n '3p' "$DIR/output.csv")
  check "window running_avg: row 2 avg_val=25" "2,A,20,25" "$ROW_2"

  # Row 3 (line 4): id=3,cat=A,value=30,avg_val=26.666666666666668
  ROW_3=$(sed -n '4p' "$DIR/output.csv")
  check "window running_avg: row 3 avg_val=26.666666666666668" "3,A,30,26.666666666666668" "$ROW_3"
else
  skip "window running_avg: row 2 avg_val=25"
  skip "window running_avg: row 3 avg_val=26.666666666666668"
fi

# =============================================================================
# 64. Window ntile
# =============================================================================
echo ""
echo "=== 64. Window ntile ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_window_ntile
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,20
3,30
4,40
5,50
6,60
7,70
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "window", "function": "ntile", "n": 3, "partition_by": [], "order_by": [{"column": "id", "order": "asc"}], "as": "tile"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  # Row 3 (line 4): id=3,value=30,tile=1
  ROW_3=$(sed -n '4p' "$DIR/output.csv")
  check "window ntile: id=3 tile=1" "3,30,1" "$ROW_3"

  # Row 4 (line 5): id=4,value=40,tile=2
  ROW_4=$(sed -n '5p' "$DIR/output.csv")
  check "window ntile: id=4 tile=2" "4,40,2" "$ROW_4"

  # Row 6 (line 7): id=6,value=60,tile=3
  ROW_6=$(sed -n '7p' "$DIR/output.csv")
  check "window ntile: id=6 tile=3" "6,60,3" "$ROW_6"
else
  skip "window ntile: id=3 tile=1"
  skip "window ntile: id=4 tile=2"
  skip "window ntile: id=6 tile=3"
fi

# =============================================================================
# 65. Window no partition (all rows in one partition)
# =============================================================================
echo ""
echo "=== 65. Window no partition ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_window_no_partition
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,30
2,10
3,20
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "window", "function": "rank", "partition_by": [], "order_by": [{"column": "value", "order": "asc"}], "as": "rnk"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  # Row 1 (line 2): id=1,value=30,rnk=3
  ROW_1=$(sed -n '2p' "$DIR/output.csv")
  check "window no partition: id=1 rnk=3" "1,30,3" "$ROW_1"

  # Row 2 (line 3): id=2,value=10,rnk=1
  ROW_2=$(sed -n '3p' "$DIR/output.csv")
  check "window no partition: id=2 rnk=1" "2,10,1" "$ROW_2"

  # Row 3 (line 4): id=3,value=20,rnk=2
  ROW_3=$(sed -n '4p' "$DIR/output.csv")
  check "window no partition: id=3 rnk=2" "3,20,2" "$ROW_3"
else
  skip "window no partition: id=1 rnk=3"
  skip "window no partition: id=2 rnk=1"
  skip "window no partition: id=3 rnk=2"
fi

# =============================================================================
# 66. Pivot basic
# =============================================================================
echo ""
echo "=== 66. Pivot basic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pivot_basic
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,metric,measurement
1,height,170
1,weight,70
2,height,180
2,weight,85
3,height,165
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "pivot", "index": ["id"], "column": "metric", "value": "measurement"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  ROW_COUNT=$(tail -n +2 "$DIR/output.csv" | wc -l | tr -d ' ')
  check "pivot basic: row count is 3" "3" "$ROW_COUNT"

  HEADER=$(head -1 "$DIR/output.csv")
  check "pivot basic: header is id,height,weight" "id,height,weight" "$HEADER"

  # Row 1 (line 2): id=1,height=170,weight=70
  ROW_1=$(sed -n '2p' "$DIR/output.csv")
  check "pivot basic: id=1 row is 1,170,70" "1,170,70" "$ROW_1"

  # Row 3 (line 4): id=3,height=165,weight= (empty)
  ROW_3=$(sed -n '4p' "$DIR/output.csv")
  check "pivot basic: id=3 row has empty weight" "3,165," "$ROW_3"
else
  skip "pivot basic: row count is 3"
  skip "pivot basic: header is id,height,weight"
  skip "pivot basic: id=1 row is 1,170,70"
  skip "pivot basic: id=3 row has empty weight"
fi

# =============================================================================
# 67. Pivot dedup (first wins)
# =============================================================================
echo ""
echo "=== 67. Pivot dedup ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pivot_dedup
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,metric,val
1,A,first
1,A,second
1,B,only
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "pivot", "index": ["id"], "column": "metric", "value": "val"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/output.csv")
  check "pivot dedup: header is id,A,B" "id,A,B" "$HEADER"

  # Row 1 (line 2): id=1,A=first,B=only
  ROW_1=$(sed -n '2p' "$DIR/output.csv")
  check "pivot dedup: first wins for A column" "1,first,only" "$ROW_1"
else
  skip "pivot dedup: header is id,A,B"
  skip "pivot dedup: first wins for A column"
fi

# =============================================================================
# 68. Unpivot basic
# =============================================================================
echo ""
echo "=== 68. Unpivot basic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_unpivot_basic
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,name,q1,q2,q3
1,Alice,10,20,30
2,Bob,40,50,60
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "unpivot", "index": ["id","name"], "columns": ["q1","q2","q3"], "name_to": "quarter", "value_to": "amount"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  ROW_COUNT=$(tail -n +2 "$DIR/output.csv" | wc -l | tr -d ' ')
  check "unpivot basic: row count is 6" "6" "$ROW_COUNT"

  HEADER=$(head -1 "$DIR/output.csv")
  check "unpivot basic: header is id,name,quarter,amount" "id,name,quarter,amount" "$HEADER"

  # Row 1 (line 2): 1,Alice,q1,10
  ROW_1=$(sed -n '2p' "$DIR/output.csv")
  check "unpivot basic: row 1 is 1,Alice,q1,10" "1,Alice,q1,10" "$ROW_1"

  # Row 4 (line 5): 2,Bob,q1,40
  ROW_4=$(sed -n '5p' "$DIR/output.csv")
  check "unpivot basic: row 4 is 2,Bob,q1,40" "2,Bob,q1,40" "$ROW_4"
else
  skip "unpivot basic: row count is 6"
  skip "unpivot basic: header is id,name,quarter,amount"
  skip "unpivot basic: row 1 is 1,Alice,q1,10"
  skip "unpivot basic: row 4 is 2,Bob,q1,40"
fi

# =============================================================================
# 69. Unpivot with empty values
# =============================================================================
echo ""
echo "=== 69. Unpivot with empty values ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_unpivot_empty
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,a,b
1,x,
2,,y
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "unpivot", "index": ["id"], "columns": ["a","b"], "name_to": "col", "value_to": "val"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  ROW_COUNT=$(tail -n +2 "$DIR/output.csv" | wc -l | tr -d ' ')
  check "unpivot empty: row count is 4" "4" "$ROW_COUNT"

  # Row 2 (line 3): 1,b, (empty val)
  ROW_2=$(sed -n '3p' "$DIR/output.csv")
  check "unpivot empty: row 2 has empty val" "1,b," "$ROW_2"

  # Row 3 (line 4): 2,a, (empty val)
  ROW_3=$(sed -n '4p' "$DIR/output.csv")
  check "unpivot empty: row 3 has empty val" "2,a," "$ROW_3"
else
  skip "unpivot empty: row count is 4"
  skip "unpivot empty: row 2 has empty val"
  skip "unpivot empty: row 3 has empty val"
fi

# =============================================================================
# 70. Window error: invalid column
# =============================================================================
echo ""
echo "=== 70. Window error: invalid column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_window_err
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "window", "function": "rank", "partition_by": ["nonexistent"], "order_by": [{"column": "id", "order": "asc"}], "as": "rnk"}]
EOF

  WIN_ERR=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>&1)
  WIN_ERR_EXIT=$?
  check "window error: exit code 1" "1" "$WIN_ERR_EXIT"
  check_contains "window error: message mentions column not found" "column nonexistent not found" "$WIN_ERR"
else
  skip "window error: exit code 1"
  skip "window error: message mentions column not found"
fi

# =============================================================================
# 71. Pivot error: invalid column
# =============================================================================
echo ""
echo "=== 71. Pivot error: invalid column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pivot_err
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,metric,measurement
1,height,170
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "pivot", "index": ["nonexistent"], "column": "metric", "value": "measurement"}]
EOF

  PIV_ERR=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>&1)
  PIV_ERR_EXIT=$?
  check "pivot error: exit code 1" "1" "$PIV_ERR_EXIT"
  check_contains "pivot error: message mentions column not found" "column nonexistent not found" "$PIV_ERR"
else
  skip "pivot error: exit code 1"
  skip "pivot error: message mentions column not found"
fi

# =============================================================================
# 72. Unpivot error: invalid column
# =============================================================================
echo ""
echo "=== 72. Unpivot error: invalid column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_unpivot_err
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,a,b
1,x,y
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "unpivot", "index": ["id"], "columns": ["nonexistent"], "name_to": "col", "value_to": "val"}]
EOF

  UNPIV_ERR=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>&1)
  UNPIV_ERR_EXIT=$?
  check "unpivot error: exit code 1" "1" "$UNPIV_ERR_EXIT"
  check_contains "unpivot error: message mentions column not found" "column nonexistent not found" "$UNPIV_ERR"
else
  skip "unpivot error: exit code 1"
  skip "unpivot error: message mentions column not found"
fi

# =============================================================================
# 73. Window multi-column order_by
# =============================================================================
echo ""
echo "=== 73. Window multi-column order_by ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_window_multi_order
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,cat,priority,value
1,A,1,100
2,A,2,200
3,A,1,300
4,A,2,100
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "window", "function": "rank", "partition_by": ["cat"], "order_by": [{"column": "priority", "order": "asc"}, {"column": "value", "order": "desc"}], "as": "rnk"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  # Row 1 (line 2): id=1,cat=A,priority=1,value=100,rnk=2
  ROW_1=$(sed -n '2p' "$DIR/output.csv")
  check "window multi order: id=1 rnk=2" "1,A,1,100,2" "$ROW_1"

  # Row 2 (line 3): id=2,cat=A,priority=2,value=200,rnk=3
  ROW_2=$(sed -n '3p' "$DIR/output.csv")
  check "window multi order: id=2 rnk=3" "2,A,2,200,3" "$ROW_2"

  # Row 3 (line 4): id=3,cat=A,priority=1,value=300,rnk=1
  ROW_3=$(sed -n '4p' "$DIR/output.csv")
  check "window multi order: id=3 rnk=1" "3,A,1,300,1" "$ROW_3"

  # Row 4 (line 5): id=4,cat=A,priority=2,value=100,rnk=4
  ROW_4=$(sed -n '5p' "$DIR/output.csv")
  check "window multi order: id=4 rnk=4" "4,A,2,100,4" "$ROW_4"
else
  skip "window multi order: id=1 rnk=2"
  skip "window multi order: id=2 rnk=3"
  skip "window multi order: id=3 rnk=1"
  skip "window multi order: id=4 rnk=4"
fi

# =============================================================================
# 74. Pivot with composite index
# =============================================================================
echo ""
echo "=== 74. Pivot with composite index ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pivot_composite
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
year,region,metric,value
2023,US,sales,100
2023,US,cost,80
2023,EU,sales,200
2024,US,sales,150
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "pivot", "index": ["year","region"], "column": "metric", "value": "value"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/output.csv" --seed 42 2>/dev/null

  ROW_COUNT=$(tail -n +2 "$DIR/output.csv" | wc -l | tr -d ' ')
  check "pivot composite: row count is 3" "3" "$ROW_COUNT"

  HEADER=$(head -1 "$DIR/output.csv")
  check "pivot composite: header is year,region,cost,sales" "year,region,cost,sales" "$HEADER"

  # Row 1 (line 2): 2023,EU,,200 (sorted: 2023,EU comes first)
  ROW_1=$(sed -n '2p' "$DIR/output.csv")
  check "pivot composite: row 1 is 2023,EU,,200" "2023,EU,,200" "$ROW_1"

  # Row 2 (line 3): 2023,US,80,100
  ROW_2=$(sed -n '3p' "$DIR/output.csv")
  check "pivot composite: row 2 is 2023,US,80,100" "2023,US,80,100" "$ROW_2"
else
  skip "pivot composite: row count is 3"
  skip "pivot composite: header is year,region,cost,sales"
  skip "pivot composite: row 1 is 2023,EU,,200"
  skip "pivot composite: row 2 is 2023,US,80,100"
fi

# =============================================================================
# 75. Expression comparison operators
# =============================================================================
echo ""
echo "=== 75. Expression comparison operators ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_expr_cmp
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,15
2,5
3,10
4,25
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "gt10", "expression": "value > 10"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "expr cmp: row 1 (15>10=1)" "1,15,1" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "expr cmp: row 2 (5>10=0)" "2,5,0" "$ROW2"

  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "expr cmp: row 3 (10>10=0)" "3,10,0" "$ROW3"
else
  skip "expr cmp: row 1 (15>10=1)"
  skip "expr cmp: row 2 (5>10=0)"
  skip "expr cmp: row 3 (10>10=0)"
fi

# =============================================================================
# 76. Expression logical operators
# =============================================================================
echo ""
echo "=== 76. Expression logical operators ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_expr_logical
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,15
2,5
3,10
4,25
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "in_range", "expression": "value > 5 && value < 20"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "expr logical AND: row 1 (15 in 5..20)" "1,15,1" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "expr logical AND: row 2 (5 not in 5..20)" "2,5,0" "$ROW2"

  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "expr logical AND: row 3 (10 in 5..20)" "3,10,1" "$ROW3"

  ROW4=$(sed -n '5p' "$DIR/out.csv")
  check "expr logical AND: row 4 (25 not in 5..20)" "4,25,0" "$ROW4"
else
  skip "expr logical AND: row 1 (15 in 5..20)"
  skip "expr logical AND: row 2 (5 not in 5..20)"
  skip "expr logical AND: row 3 (10 in 5..20)"
  skip "expr logical AND: row 4 (25 not in 5..20)"
fi

# =============================================================================
# 77. Expression OR operator
# =============================================================================
echo ""
echo "=== 77. Expression OR operator ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_expr_or
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,15
2,5
3,10
4,25
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "extreme", "expression": "value < 10 || value > 20"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "expr OR: row 2 (5<10=true)" "2,5,1" "$ROW2"

  ROW4=$(sed -n '5p' "$DIR/out.csv")
  check "expr OR: row 4 (25>20=true)" "4,25,1" "$ROW4"
else
  skip "expr OR: row 2 (5<10=true)"
  skip "expr OR: row 4 (25>20=true)"
fi

# =============================================================================
# 78. Expression equality operators
# =============================================================================
echo ""
echo "=== 78. Expression equality operators ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_expr_eq
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,15
2,5
3,10
4,25
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "is10", "expression": "value == 10"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "expr eq: row 3 (10==10=1)" "3,10,1" "$ROW3"

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "expr eq: row 1 (15==10=0)" "1,15,0" "$ROW1"
else
  skip "expr eq: row 3 (10==10=1)"
  skip "expr eq: row 1 (15==10=0)"
fi

# =============================================================================
# 79. Expression != operator
# =============================================================================
echo ""
echo "=== 79. Expression != operator ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_expr_neq
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,15
2,5
3,10
4,25
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "not10", "expression": "value != 10"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "expr neq: row 3 (10!=10=0)" "3,10,0" "$ROW3"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "expr neq: row 2 (5!=10=1)" "2,5,1" "$ROW2"
else
  skip "expr neq: row 3 (10!=10=0)"
  skip "expr neq: row 2 (5!=10=1)"
fi

# =============================================================================
# 80. Expression operator precedence
# =============================================================================
echo ""
echo "=== 80. Expression operator precedence ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_expr_prec
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "value + 5 > 12"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "expr precedence: (10+5)>12=1" "1,10,1" "$ROW1"
else
  skip "expr precedence: (10+5)>12=1"
fi

# =============================================================================
# 81. Expression unary negation
# =============================================================================
echo ""
echo "=== 81. Expression unary negation ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_expr_neg
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,5
2,-3
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "neg", "expression": "-value"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "expr negation: -5 from 5" "1,5,-5" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "expr negation: 3 from -3" "2,-3,3" "$ROW2"
else
  skip "expr negation: -5 from 5"
  skip "expr negation: 3 from -3"
fi

# =============================================================================
# 82. Clamp function
# =============================================================================
echo ""
echo "=== 82. Clamp function ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_clamp
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,5
2,15
3,25
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "clamped", "expression": "clamp(value, 10, 20)"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "clamp: 5 clamped to 10" "1,5,10" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "clamp: 15 stays 15" "2,15,15" "$ROW2"

  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "clamp: 25 clamped to 20" "3,25,20" "$ROW3"
else
  skip "clamp: 5 clamped to 10"
  skip "clamp: 15 stays 15"
  skip "clamp: 25 clamped to 20"
fi

# =============================================================================
# 83. Coalesce function
# =============================================================================
echo ""
echo "=== 83. Coalesce function ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_coalesce
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,a,b
1,10,0
2,6,2
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "safe", "expression": "coalesce(a / b, -1)"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "coalesce: NaN replaced with -1" "1,10,0,-1" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "coalesce: valid 3 kept" "2,6,2,3" "$ROW2"
else
  skip "coalesce: NaN replaced with -1"
  skip "coalesce: valid 3 kept"
fi

# =============================================================================
# 84. NaN in comparisons
# =============================================================================
echo ""
echo "=== 84. NaN in comparisons ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_nan_cmp
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,a,b
1,10,0
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "cmp", "expression": "(a / b) > 5"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "NaN cmp: NaN>5=0" "1,10,0,0" "$ROW1"
else
  skip "NaN cmp: NaN>5=0"
fi

# =============================================================================
# 85. Having in aggregate
# =============================================================================
echo ""
echo "=== 85. Having in aggregate ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_having
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,label,value
1,A,10
2,A,20
3,A,30
4,B,5
5,B,15
6,C,100
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "aggregate", "group_by": ["label"], "aggregations": [{"column": "value", "function": "sum", "as": "total"}], "having": {"column": "total", "condition": "gte", "threshold": 20}}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW_COUNT=$(tail -n +2 "$DIR/out.csv" | wc -l | tr -d ' ')
  check "having gte 20: row count=3" "3" "$ROW_COUNT"

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "having gte 20: row 1=A,60" "A,60" "$ROW1"
else
  skip "having gte 20: row count=3"
  skip "having gte 20: row 1=A,60"
fi

# =============================================================================
# 86. Having filters groups
# =============================================================================
echo ""
echo "=== 86. Having filters groups ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_having_filter
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,label,value
1,A,10
2,A,20
3,A,30
4,B,5
5,B,15
6,C,100
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "aggregate", "group_by": ["label"], "aggregations": [{"column": "value", "function": "sum", "as": "total"}], "having": {"column": "total", "condition": "gt", "threshold": 50}}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW_COUNT=$(tail -n +2 "$DIR/out.csv" | wc -l | tr -d ' ')
  check "having gt 50: row count=2" "2" "$ROW_COUNT"

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "having gt 50: row 1=A,60" "A,60" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "having gt 50: row 2=C,100" "C,100" "$ROW2"
else
  skip "having gt 50: row count=2"
  skip "having gt 50: row 1=A,60"
  skip "having gt 50: row 2=C,100"
fi

# =============================================================================
# 87. Fill forward
# =============================================================================
echo ""
echo "=== 87. Fill forward ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_fill_fwd
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,
3,
4,20
5,
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "fill", "columns": ["value"], "strategy": "forward"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "fill forward: row 2=2,10" "2,10" "$ROW2"

  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "fill forward: row 3=3,10" "3,10" "$ROW3"

  ROW5=$(sed -n '6p' "$DIR/out.csv")
  check "fill forward: row 5=5,20" "5,20" "$ROW5"
else
  skip "fill forward: row 2=2,10"
  skip "fill forward: row 3=3,10"
  skip "fill forward: row 5=5,20"
fi

# =============================================================================
# 88. Fill backward
# =============================================================================
echo ""
echo "=== 88. Fill backward ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_fill_bwd
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,
3,
4,20
5,
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "fill", "columns": ["value"], "strategy": "backward"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "fill backward: row 2=2,20" "2,20" "$ROW2"

  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "fill backward: row 3=3,20" "3,20" "$ROW3"

  ROW5=$(sed -n '6p' "$DIR/out.csv")
  check "fill backward: row 5=5," "5," "$ROW5"
else
  skip "fill backward: row 2=2,20"
  skip "fill backward: row 3=3,20"
  skip "fill backward: row 5=5,"
fi

# =============================================================================
# 89. Fill constant
# =============================================================================
echo ""
echo "=== 89. Fill constant ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_fill_const
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,
3,
4,20
5,
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "fill", "columns": ["value"], "strategy": "constant", "value": "0"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "fill constant: row 2=2,0" "2,0" "$ROW2"

  ROW5=$(sed -n '6p' "$DIR/out.csv")
  check "fill constant: row 5=5,0" "5,0" "$ROW5"
else
  skip "fill constant: row 2=2,0"
  skip "fill constant: row 5=5,0"
fi

# =============================================================================
# 90. Fill forward leading empty
# =============================================================================
echo ""
echo "=== 90. Fill forward leading empty ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_fill_lead
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,
2,
3,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "fill", "columns": ["value"], "strategy": "forward"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "fill forward leading: row 1=1," "1," "$ROW1"

  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "fill forward leading: row 3=3,10" "3,10" "$ROW3"
else
  skip "fill forward leading: row 1=1,"
  skip "fill forward leading: row 3=3,10"
fi

# =============================================================================
# 91. Fill error: invalid column
# =============================================================================
echo ""
echo "=== 91. Fill error: invalid column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_fill_err
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,
3,
4,20
5,
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "fill", "columns": ["nonexistent"], "strategy": "forward"}]
EOF

  FILL_ERR=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>&1)
  FILL_ERR_EXIT=$?
  check "fill error: exit code 1" "1" "$FILL_ERR_EXIT"
  check_contains "fill error: column nonexistent not found" "column nonexistent not found" "$FILL_ERR"
else
  skip "fill error: exit code 1"
  skip "fill error: column nonexistent not found"
fi

# =============================================================================
# 92. Complex expression with all operator types
# =============================================================================
echo ""
echo "=== 92. Complex expression with all operator types ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_expr_complex
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,a,b
1,10,2
2,5,0
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "derive", "name": "result", "expression": "if(a > 5 && b != 0, a / b, -1)"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "complex expr: row 1 (10>5 && 2!=0 -> 10/2=5)" "1,10,2,5" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "complex expr: row 2 (5>5=false -> -1)" "2,5,0,-1" "$ROW2"
else
  skip "complex expr: row 1 (10>5 && 2!=0 -> 10/2=5)"
  skip "complex expr: row 2 (5>5=false -> -1)"
fi

# =============================================================================
# Summary and reward
# =============================================================================
echo ""
echo "========================================="
echo "========================================="


# --- Canonical machine-readable per-case summaries (no status= tokens here) ---
echo "CASE_SUMMARY total_cases=$TOTAL success_count=$PASS fail_count=$((TOTAL - PASS))"
for k in $(printf '%s\n' "${!ORIGIN_TOTAL[@]}" | sort); do
  t=${ORIGIN_TOTAL[$k]}; s=${ORIGIN_SUCCESS[$k]:-0}
  echo "CASE_SUMMARY_BY_ORIGIN origin_step=$k total_cases=$t success_count=$s fail_count=$((t - s))"
done
for k in $(printf '%s\n' "${!REQ_TOTAL[@]}" | sort); do
  t=${REQ_TOTAL[$k]}; s=${REQ_SUCCESS[$k]:-0}
  echo "CASE_SUMMARY_BY_REQUIREMENT requirement_ref=$k total_cases=$t success_count=$s fail_count=$((t - s))"
done
for k in $(printf '%s\n' "${!TYPE_TOTAL[@]}" | sort); do
  t=${TYPE_TOTAL[$k]}; s=${TYPE_SUCCESS[$k]:-0}
  echo "CASE_SUMMARY_BY_TYPE case_type=$k total_cases=$t success_count=$s fail_count=$((t - s))"
done
for k in $(printf '%s\n' "${!FAILCAT[@]}" | sort); do
  echo "CASE_FAILURE_CATEGORY category=$k fail_count=${FAILCAT[$k]}"
done


mkdir -p /logs/verifier
if [ "$TOTAL" -gt 0 ]; then
  if [ "$PASS" -eq "$TOTAL" ]; then REWARD="1.0"; else REWARD="0.0"; fi
else
  REWARD=0
fi
echo "$REWARD" > /logs/verifier/reward.txt
