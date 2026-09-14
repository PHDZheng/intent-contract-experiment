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
reg "basic ingest: no .sha256 sidecar" round-1 ingest core "Basic ingest" "basic ingest: no .sha256 sidecar"
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
reg "manifest detail: BLAKE2b matches" round-1 manifest integration "Manifest row count and size" "manifest detail: BLAKE2b matches"
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
reg "transform: no .sha256 sidecar produced" round-1 determinism core "Transform SHA-256" "transform: no .sha256 sidecar produced"
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
reg "profile int: output file exists" round-2 profile core "Profile command - integer column" "profile int: output file exists"
reg "profile int: row_count" round-2 profile core "Profile command - integer column" "profile int: row_count"
reg "profile int: id column type" round-2 profile core "Profile command - integer column" "profile int: id column type"
reg "profile int: id count" round-2 profile core "Profile command - integer column" "profile int: id count"
reg "profile int: id unique" round-2 profile core "Profile command - integer column" "profile int: id unique"
reg "profile int: id null_count" round-2 profile core "Profile command - integer column" "profile int: id null_count"
reg "profile int: id min" round-2 profile core "Profile command - integer column" "profile int: id min"
reg "profile int: id max" round-2 profile core "Profile command - integer column" "profile int: id max"
reg "profile int: id mean" round-2 profile core "Profile command - integer column" "profile int: id mean"
reg "profile int: value mean" round-2 profile core "Profile command - integer column" "profile int: value mean"
reg "profile int: value median" round-2 profile core "Profile command - integer column" "profile int: value median"
reg "profile int: value min" round-2 profile core "Profile command - integer column" "profile int: value min"
reg "profile int: value max" round-2 profile core "Profile command - integer column" "profile int: value max"
reg "profile float: score type" round-2 profile core "Profile command - float column" "profile float: score type"
reg "profile float: score min" round-2 profile core "Profile command - float column" "profile float: score min"
reg "profile float: score max" round-2 profile core "Profile command - float column" "profile float: score max"
reg "profile float: score mean" round-2 profile core "Profile command - float column" "profile float: score mean"
reg "profile float: score median" round-2 profile core "Profile command - float column" "profile float: score median"
reg "profile float: score p25" round-2 profile core "Profile command - float column" "profile float: score p25"
reg "profile float: score p75" round-2 profile core "Profile command - float column" "profile float: score p75"
reg "profile string: label type" round-2 profile core "Profile command - string column" "profile string: label type"
reg "profile string: label count" round-2 profile core "Profile command - string column" "profile string: label count"
reg "profile string: label null_count" round-2 profile core "Profile command - string column" "profile string: label null_count"
reg "profile string: label unique" round-2 profile core "Profile command - string column" "profile string: label unique"
reg "profile string: label min_length" round-2 profile core "Profile command - string column" "profile string: label min_length"
reg "profile string: label max_length" round-2 profile core "Profile command - string column" "profile string: label max_length"
reg "profile string: most_common[0] value" round-2 profile core "Profile command - string column" "profile string: most_common[0] value"
reg "profile string: most_common[0] count" round-2 profile core "Profile command - string column" "profile string: most_common[0] count"
reg "profile string: most_common[1] value" round-2 profile core "Profile command - string column" "profile string: most_common[1] value"
reg "profile string: most_common length" round-2 profile core "Profile command - string column" "profile string: most_common length"
reg "profile datetime: ts type" round-2 profile core "Profile command - datetime column" "profile datetime: ts type"
reg "profile datetime: earliest" round-2 profile core "Profile command - datetime column" "profile datetime: earliest"
reg "profile datetime: latest" round-2 profile core "Profile command - datetime column" "profile datetime: latest"
reg "profile datetime: count" round-2 profile core "Profile command - datetime column" "profile datetime: count"
reg "profile empty: type is string" round-2 profile boundary "Profile command - empty column" "profile empty: type is string"
reg "profile empty: count is 0" round-2 profile boundary "Profile command - empty column" "profile empty: count is 0"
reg "profile empty: null_count is 3" round-2 profile boundary "Profile command - empty column" "profile empty: null_count is 3"
reg "profile empty: min_length is 0" round-2 profile boundary "Profile command - empty column" "profile empty: min_length is 0"
reg "profile empty: most_common is empty" round-2 profile boundary "Profile command - empty column" "profile empty: most_common is empty"
reg "profile single: stddev is 0" round-2 profile boundary "Profile command - single value column" "profile single: stddev is 0"
reg "profile single: median is 42" round-2 profile boundary "Profile command - single value column" "profile single: median is 42"
reg "profile single: p25 is 42" round-2 profile boundary "Profile command - single value column" "profile single: p25 is 42"
reg "profile pct: p25 interpolation" round-2 profile core "Profile command - percentile interpolation" "profile pct: p25 interpolation"
reg "profile pct: median interpolation" round-2 profile core "Profile command - percentile interpolation" "profile pct: median interpolation"
reg "profile pct: p75 interpolation" round-2 profile core "Profile command - percentile interpolation" "profile pct: p75 interpolation"
reg "profile stddev: population stddev" round-2 profile core "Profile command - stddev calculation" "profile stddev: population stddev"
reg "profile mc tie: first is Alpha" round-2 profile core "Profile command - most_common tiebreaking" "profile mc tie: first is Alpha"
reg "profile mc tie: second is Zebra" round-2 profile core "Profile command - most_common tiebreaking" "profile mc tie: second is Zebra"
reg "profile mc tie: third is Middle" round-2 profile core "Profile command - most_common tiebreaking" "profile mc tie: third is Middle"
reg "profile missing file: exit code 1" round-1 error-handling error "Profile command - missing file error" "profile missing file: exit code 1"
reg "profile missing file: error message" round-1 error-handling error "Profile command - missing file error" "profile missing file: error message"
reg "dedup first: row count is 3" round-2 transform.deduplicate error "Deduplicate transform - keep first" "dedup first: row count is 3"
reg "dedup first: row 1 is Alice(100)" round-2 transform.deduplicate error "Deduplicate transform - keep first" "dedup first: row 1 is Alice(100)"
reg "dedup first: row 2 is Bob(200)" round-2 transform.deduplicate error "Deduplicate transform - keep first" "dedup first: row 2 is Bob(200)"
reg "dedup first: row 3 is Charlie(400)" round-2 transform.deduplicate error "Deduplicate transform - keep first" "dedup first: row 3 is Charlie(400)"
reg "dedup last: row count is 3" round-2 transform.deduplicate error "Deduplicate transform - keep last" "dedup last: row count is 3"
reg "dedup last: row 1 is Alice(300)" round-2 transform.deduplicate error "Deduplicate transform - keep last" "dedup last: row 1 is Alice(300)"
reg "dedup last: row 2 is Charlie(400)" round-2 transform.deduplicate error "Deduplicate transform - keep last" "dedup last: row 2 is Charlie(400)"
reg "dedup last: row 3 is Bob(500)" round-2 transform.deduplicate error "Deduplicate transform - keep last" "dedup last: row 3 is Bob(500)"
reg "dedup all cols: row count is 3" round-2 transform.deduplicate error "Deduplicate transform - all columns" "dedup all cols: row count is 3"
reg "dedup all cols: row 1" round-2 transform.deduplicate error "Deduplicate transform - all columns" "dedup all cols: row 1"
reg "dedup missing col: exit code 1" round-1 error-handling error "Deduplicate transform - missing column error" "dedup missing col: exit code 1"
reg "dedup missing col: error mentions column" round-1 error-handling error "Deduplicate transform - missing column error" "dedup missing col: error mentions column"
reg "split basic: header" round-2 transform.split core "Split transform - basic" "split basic: header"
reg "split basic: row 1" round-2 transform.split core "Split transform - basic" "split basic: row 1"
reg "split basic: row 2" round-2 transform.split core "Split transform - basic" "split basic: row 2"
reg "split fewer: header" round-2 transform.split core "Split transform - fewer parts than names" "split fewer: header"
reg "split fewer: row 1 (no delimiter found)" round-2 transform.split core "Split transform - fewer parts than names" "split fewer: row 1 (no delimiter found)"
reg "split more: row 1 (remainder)" round-2 transform.split core "Split transform - more parts than names" "split more: row 1 (remainder)"
reg "split more: row 2 (exact)" round-2 transform.split core "Split transform - more parts than names" "split more: row 2 (exact)"
reg "split pos: columns at correct position" round-2 transform.split core "Split transform - column position preserved" "split pos: columns at correct position"
reg "split pos: row values" round-2 transform.split core "Split transform - column position preserved" "split pos: row values"
reg "split missing col: exit code 1" round-1 error-handling error "Split transform - missing column error" "split missing col: exit code 1"
reg "split missing col: error message" round-1 error-handling error "Split transform - missing column error" "split missing col: error message"
reg "assert pass: exit code 0" round-2 transform.assert core "Assert transform - pass" "assert pass: exit code 0"
reg "assert pass: rows preserved" round-2 transform.assert core "Assert transform - pass" "assert pass: rows preserved"
reg "assert fail: exit code 1" round-2 transform.assert error "Assert transform - fail" "assert fail: exit code 1"
reg "assert fail: error mentions row 2" round-2 transform.assert error "Assert transform - fail" "assert fail: error mentions row 2"
reg "assert fail: error message" round-2 transform.assert error "Assert transform - fail" "assert fail: error message"
reg "assert complex: all rows pass" round-1 transform.derive core "Assert transform - complex expression" "assert complex: all rows pass"
reg "pipeline profile: exit code 0" round-1 pipeline integration "Pipeline with profile step" "pipeline profile: exit code 0"
reg "pipeline profile: OK message" round-1 pipeline integration "Pipeline with profile step" "pipeline profile: OK message"
reg "pipeline profile: output file created" round-1 pipeline integration "Pipeline with profile step" "pipeline profile: output file created"
reg "pipeline profile: row_count correct" round-1 pipeline integration "Pipeline with profile step" "pipeline profile: row_count correct"
reg "profile mixed: non-int non-float -> string" round-2 profile core "Profile type inference - mixed values" "profile mixed: non-int non-float -> string"
reg "dedup+sort: first row id=1" round-2 transform.deduplicate error "Deduplicate then sort chain" "dedup+sort: first row id=1"
reg "dedup+sort: second row id=3" round-2 transform.deduplicate error "Deduplicate then sort chain" "dedup+sort: second row id=3"
reg "dedup+sort: third row id=4" round-2 transform.deduplicate error "Deduplicate then sort chain" "dedup+sort: third row id=4"
reg "split+derive: header" round-1 transform.derive integration "Split then derive chain" "split+derive: header"
reg "split+derive: row 1 sum" round-1 transform.derive integration "Split then derive chain" "split+derive: row 1 sum"
reg "assert+filter: exit code 0" round-2 transform.assert integration "Assert then filter chain" "assert+filter: exit code 0"
reg "assert+filter: 3 rows after filter" round-2 transform.assert integration "Assert then filter chain" "assert+filter: 3 rows after filter"
reg "profile nullnum: value count" round-2 profile core "Profile with nulls in numeric column" "profile nullnum: value count"
reg "profile nullnum: value null_count" round-2 profile core "Profile with nulls in numeric column" "profile nullnum: value null_count"
reg "profile nullnum: value mean" round-2 profile core "Profile with nulls in numeric column" "profile nullnum: value mean"
reg "profile nullnum: value median" round-2 profile core "Profile with nulls in numeric column" "profile nullnum: value median"
reg "corr positive: pair count" round-2 profile integration "Profile correlations: perfect positive" "corr positive: pair count"
reg "corr positive: r=1" round-2 profile integration "Profile correlations: perfect positive" "corr positive: r=1"
reg "corr zero stddev: pair count" round-2 profile boundary "Profile correlations: zero stddev" "corr zero stddev: pair count"
reg "corr zero stddev: null" round-2 profile boundary "Profile correlations: zero stddev" "corr zero stddev: null"
reg "corr insufficient: null" round-2 profile integration "Profile correlations: insufficient pairs" "corr insufficient: null"
reg "corr numonly: pair count" round-2 profile integration "Profile correlations: only numeric" "corr numonly: pair count"
reg "corr numonly: column_a" round-2 profile integration "Profile correlations: only numeric" "corr numonly: column_a"
reg "corr numonly: column_b" round-2 profile integration "Profile correlations: only numeric" "corr numonly: column_b"
reg "corr numonly: r=-1" round-2 profile integration "Profile correlations: only numeric" "corr numonly: r=-1"
reg "norm zscore: header" round-2 transform.normalize core "Normalize zscore basic" "norm zscore: header"
reg "norm zscore: row1 z=-0.7071" round-2 transform.normalize core "Normalize zscore basic" "norm zscore: row1 z=-0.7071"
reg "norm zscore: row2 z=0.7071" round-2 transform.normalize core "Normalize zscore basic" "norm zscore: row2 z=0.7071"
reg "norm minmax: row1=0" round-2 transform.normalize core "Normalize minmax basic" "norm minmax: row1=0"
reg "norm minmax: row2=0.5" round-2 transform.normalize core "Normalize minmax basic" "norm minmax: row2=0.5"
reg "norm minmax: row3=1" round-2 transform.normalize core "Normalize minmax basic" "norm minmax: row3=1"
reg "norm zscore zero stddev: row1=0" round-2 transform.normalize boundary "Normalize zscore zero stddev" "norm zscore zero stddev: row1=0"
reg "norm zscore zero stddev: row3=0" round-2 transform.normalize boundary "Normalize zscore zero stddev" "norm zscore zero stddev: row3=0"
reg "norm minmax same: row1=0" round-2 transform.normalize core "Normalize minmax all same" "norm minmax same: row1=0"
reg "norm minmax same: row2=0" round-2 transform.normalize core "Normalize minmax all same" "norm minmax same: row2=0"
reg "norm mixed: row1 z=-0.7071" round-2 transform.normalize boundary "Normalize non-numeric and empty" "norm mixed: row1 z=-0.7071"
reg "norm mixed: row2 non-numeric empty" round-2 transform.normalize boundary "Normalize non-numeric and empty" "norm mixed: row2 non-numeric empty"
reg "norm mixed: row3 empty stays empty" round-2 transform.normalize boundary "Normalize non-numeric and empty" "norm mixed: row3 empty stays empty"
reg "norm mixed: row4 z=0.7071" round-2 transform.normalize boundary "Normalize non-numeric and empty" "norm mixed: row4 z=0.7071"
reg "norm missing col: exit code 1" round-1 error-handling error "Normalize missing column error" "norm missing col: exit code 1"
reg "fill linear: row2=20" round-1 transform.fill core "Fill linear basic" "fill linear: row2=20"
reg "fill linear: row3=30" round-1 transform.fill core "Fill linear basic" "fill linear: row3=30"
reg "fill linear bound: row1 extrapolated" round-1 transform.fill core "Fill linear boundaries" "fill linear bound: row1 extrapolated"
reg "fill linear bound: row3=15" round-1 transform.fill core "Fill linear boundaries" "fill linear bound: row3=15"
reg "fill linear bound: row5 extrapolated" round-1 transform.fill core "Fill linear boundaries" "fill linear bound: row5 extrapolated"
reg "fill linear nonum: row2 unchanged abc" round-1 transform.fill core "Fill linear non-numeric" "fill linear nonum: row2 unchanged abc"
reg "fill linear nonum: row3=30" round-1 transform.fill core "Fill linear non-numeric" "fill linear nonum: row3=30"
reg "fill linear multi: row2=10" round-1 transform.fill core "Fill linear multiple gaps" "fill linear multi: row2=10"
reg "fill linear multi: row3=20" round-1 transform.fill core "Fill linear multiple gaps" "fill linear multi: row3=20"
reg "fill linear multi: row4=30" round-1 transform.fill core "Fill linear multiple gaps" "fill linear multi: row4=30"
reg "fill linear multi: row5=40" round-1 transform.fill core "Fill linear multiple gaps" "fill linear multi: row5=40"
reg "corr negative: r=-1" round-2 profile boundary "Profile negative correlation" "corr negative: r=-1"
reg "corr three cols: 3 pairs" round-2 profile core "Profile three numeric columns" "corr three cols: 3 pairs"
reg "corr three cols: ab=1" round-2 profile core "Profile three numeric columns" "corr three cols: ab=1"
reg "corr float: pair count" round-2 profile integration "Profile correlations float columns" "corr float: pair count"
reg "corr float: r=1" round-2 profile integration "Profile correlations float columns" "corr float: r=1"
reg "norm derive chain: has norm" round-1 transform.derive integration "Normalize + derive chain" "norm derive chain: has norm"
reg "norm derive chain: has double_norm" round-1 transform.derive integration "Normalize + derive chain" "norm derive chain: has double_norm"
reg "norm derive chain: row2 double_norm=1" round-1 transform.derive integration "Normalize + derive chain" "norm derive chain: row2 double_norm=1"
reg "fill assert chain: exit 0" round-1 transform.fill integration "Fill linear + assert chain" "fill assert chain: exit 0"
reg "fill assert chain: row2=20" round-1 transform.fill integration "Fill linear + assert chain" "fill assert chain: row2=20"
reg "fill norm chain: has norm" round-1 transform.fill integration "Fill linear + normalize chain" "fill norm chain: has norm"
reg "fill norm chain: row1 norm=0" round-1 transform.fill integration "Fill linear + normalize chain" "fill norm chain: row1 norm=0"
reg "fill norm chain: row2 norm=0.5" round-1 transform.fill integration "Fill linear + normalize chain" "fill norm chain: row2 norm=0.5"
reg "fill norm chain: row3 norm=1" round-1 transform.fill integration "Fill linear + normalize chain" "fill norm chain: row3 norm=1"
reg "fill norm chain: row4 norm=0.5" round-1 transform.fill integration "Fill linear + normalize chain" "fill norm chain: row4 norm=0.5"
reg "corr one col: empty array" round-2 profile core "Profile one numeric column" "corr one col: empty array"
reg "corr partial: r=1" round-2 profile error "Profile corr partial missing" "corr partial: r=1"
reg "hash basic: header" round-2 transform.hash boundary "Hash basic - single column" "hash basic: header"
reg "hash basic: row1" round-2 transform.hash boundary "Hash basic - single column" "hash basic: row1"
reg "hash multi: row1" round-2 transform.hash integration "Hash multi-column with null separator" "hash multi: row1"
reg "hash all cols: row1" round-2 transform.hash core "Hash all columns" "hash all cols: row1"
reg "hash empty cell: row1" round-2 transform.hash boundary "Hash with empty cell" "hash empty cell: row1"
reg "hash col err" round-2 transform.hash error "Hash column not found" "hash col err"
reg "cmp basic: left_rows" round-2 compare core "Compare basic" "cmp basic: left_rows"
reg "cmp basic: right_rows" round-2 compare core "Compare basic" "cmp basic: right_rows"
reg "cmp basic: added" round-2 compare core "Compare basic" "cmp basic: added"
reg "cmp basic: removed" round-2 compare core "Compare basic" "cmp basic: removed"
reg "cmp basic: modified" round-2 compare core "Compare basic" "cmp basic: modified"
reg "cmp basic: unchanged" round-2 compare core "Compare basic" "cmp basic: unchanged"
reg "cmp order: first=added" round-2 compare core "Compare changes ordering" "cmp order: first=added"
reg "cmp order: added key" round-2 compare core "Compare changes ordering" "cmp order: added key"
reg "cmp order: second=removed" round-2 compare core "Compare changes ordering" "cmp order: second=removed"
reg "cmp order: removed key" round-2 compare core "Compare changes ordering" "cmp order: removed key"
reg "cmp order: third=modified" round-2 compare core "Compare changes ordering" "cmp order: third=modified"
reg "cmp order: diff col" round-2 compare core "Compare changes ordering" "cmp order: diff col"
reg "cmp compkey: added" round-2 compare integration "Compare composite key" "cmp compkey: added"
reg "cmp compkey: removed" round-2 compare integration "Compare composite key" "cmp compkey: removed"
reg "cmp compkey: modified" round-2 compare integration "Compare composite key" "cmp compkey: modified"
reg "cmp compkey: unchanged" round-2 compare integration "Compare composite key" "cmp compkey: unchanged"
reg "cmp schema err" round-2 compare error "Compare schema mismatch" "cmp schema err"
reg "cmp no key err" round-2 compare error "Compare missing key" "cmp no key err"
reg "cmp bad key err" round-2 compare error "Compare invalid key column" "cmp bad key err"
reg "cmp file not found" round-2 compare error "Compare file not found" "cmp file not found"
reg "cmp ident: added" round-2 compare boundary "Compare identical files" "cmp ident: added"
reg "cmp ident: removed" round-2 compare boundary "Compare identical files" "cmp ident: removed"
reg "cmp ident: modified" round-2 compare boundary "Compare identical files" "cmp ident: modified"
reg "cmp ident: unchanged" round-2 compare boundary "Compare identical files" "cmp ident: unchanged"
reg "cmp ident: changes empty" round-2 compare boundary "Compare identical files" "cmp ident: changes empty"
reg "cmp dup: modified" round-2 compare error "Compare duplicate keys" "cmp dup: modified"
reg "cmp dup: left name" round-2 compare error "Compare duplicate keys" "cmp dup: left name"
reg "cmp diff: col0" round-2 compare core "Compare modified diff field" "cmp diff: col0"
reg "cmp diff: col1" round-2 compare core "Compare modified diff field" "cmp diff: col1"
reg "cmp pipe: added" round-1 pipeline integration "Compare pipeline step" "cmp pipe: added"
reg "cmp pipe: removed" round-1 pipeline integration "Compare pipeline step" "cmp pipe: removed"
reg "hash deterministic" round-2 transform.hash core "Hash deterministic" "hash deterministic"
reg "cmp no output err" round-2 compare error "Compare missing output" "cmp no output err"
reg "hash+cmp e2e: modified" round-2 compare core "Hash + Compare e2e" "hash+cmp e2e: modified"
reg "hash+cmp e2e: diff cols" round-2 compare core "Hash + Compare e2e" "hash+cmp e2e: diff cols"
reg "cmp added content: name" round-2 compare core "Compare added row content" "cmp added content: name"
reg "cmp added content: id" round-2 compare core "Compare added row content" "cmp added content: id"
reg "profile skewness right-skewed" round-2 profile core "Profile skewness (right-skewed)" "profile skewness right-skewed"
reg "profile skewness symmetric" round-2 profile core "Profile skewness (symmetric)" "profile skewness symmetric"
reg "profile skewness null n<3" round-2 profile core "Profile skewness null (n<3)" "profile skewness null n<3"
reg "profile kurtosis" round-2 profile core "Profile kurtosis" "profile kurtosis"
reg "profile kurtosis symmetric" round-2 profile core "Profile kurtosis symmetric" "profile kurtosis symmetric"
reg "profile kurtosis null n<4" round-2 profile core "Profile kurtosis null (n<4)" "profile kurtosis null n<4"
reg "profile mode basic" round-2 profile core "Profile mode basic" "profile mode basic"
reg "profile mode tie smallest" round-2 profile core "Profile mode tie" "profile mode tie smallest"
reg "profile mode null unique" round-2 profile core "Profile mode null" "profile mode null unique"
reg "profile histogram length" round-2 profile core "Profile histogram basic" "profile histogram length"
reg "profile histogram bin0" round-2 profile core "Profile histogram basic" "profile histogram bin0"
reg "profile histogram bin9" round-2 profile core "Profile histogram basic" "profile histogram bin9"
reg "profile histogram bin0 low" round-2 profile core "Profile histogram basic" "profile histogram bin0 low"
reg "profile histogram identical length" round-2 profile boundary "Profile histogram identical" "profile histogram identical length"
reg "profile histogram identical count" round-2 profile boundary "Profile histogram identical" "profile histogram identical count"
reg "profile histogram identical low" round-2 profile boundary "Profile histogram identical" "profile histogram identical low"
reg "profile avg_length" round-2 profile core "Profile avg_length" "profile avg_length"
reg "encode onehot drop header" round-1 transform.rename-drop core "Encode onehot drop" "encode onehot drop header"
reg "encode onehot drop row1" round-1 transform.rename-drop core "Encode onehot drop" "encode onehot drop row1"
reg "encode onehot drop row2" round-1 transform.rename-drop core "Encode onehot drop" "encode onehot drop row2"
reg "encode onehot nodrop header" round-1 transform.rename-drop core "Encode onehot no-drop" "encode onehot nodrop header"
reg "encode onehot nodrop row1" round-1 transform.rename-drop core "Encode onehot no-drop" "encode onehot nodrop row1"
reg "encode ordinal header" round-2 transform.encode core "Encode ordinal" "encode ordinal header"
reg "encode ordinal row1 high" round-2 transform.encode core "Encode ordinal" "encode ordinal row1 high"
reg "encode ordinal row2 low" round-2 transform.encode core "Encode ordinal" "encode ordinal row2 low"
reg "encode ordinal row3 medium" round-2 transform.encode core "Encode ordinal" "encode ordinal row3 medium"
reg "rollup single header" round-2 transform.rollup boundary "Rollup single column" "rollup single header"
reg "rollup single row1 East" round-2 transform.rollup boundary "Rollup single column" "rollup single row1 East"
reg "rollup single row2 West" round-2 transform.rollup boundary "Rollup single column" "rollup single row2 West"
reg "rollup single grand total" round-2 transform.rollup boundary "Rollup single column" "rollup single grand total"
reg "rollup two header" round-2 transform.rollup core "Rollup two columns" "rollup two header"
reg "rollup two detail1" round-2 transform.rollup core "Rollup two columns" "rollup two detail1"
reg "rollup two detail2" round-2 transform.rollup core "Rollup two columns" "rollup two detail2"
reg "rollup two detail3" round-2 transform.rollup core "Rollup two columns" "rollup two detail3"
reg "rollup two detail4" round-2 transform.rollup core "Rollup two columns" "rollup two detail4"
reg "rollup two subtotal East" round-2 transform.rollup core "Rollup two columns" "rollup two subtotal East"
reg "rollup two subtotal West" round-2 transform.rollup core "Rollup two columns" "rollup two subtotal West"
reg "rollup two grand total" round-2 transform.rollup core "Rollup two columns" "rollup two grand total"
reg "detect iqr normal val=1" round-2 transform.detect core "Detect IQR" "detect iqr normal val=1"
reg "detect iqr outlier val=100" round-2 transform.detect core "Detect IQR" "detect iqr outlier val=100"
reg "detect zscore normal val=10" round-2 transform.detect core "Detect zscore" "detect zscore normal val=10"
reg "detect zscore outlier val=100" round-2 transform.detect core "Detect zscore" "detect zscore outlier val=100"
reg "detect mad normal val=1" round-2 transform.detect core "Detect MAD" "detect mad normal val=1"
reg "detect mad outlier val=100" round-2 transform.detect core "Detect MAD" "detect mad outlier val=100"
reg "detect mad0 val=5 not outlier" round-2 transform.detect core "Detect MAD zero" "detect mad0 val=5 not outlier"
reg "detect mad0 val=99 outlier" round-2 transform.detect core "Detect MAD zero" "detect mad0 val=99 outlier"
reg "bin width val=0" round-2 transform.bin core "Bin width" "bin width val=0"
reg "bin width val=25" round-2 transform.bin core "Bin width" "bin width val=25"
reg "bin width val=100 last" round-2 transform.bin core "Bin width" "bin width val=100 last"
reg "bin quantile val=1" round-2 transform.bin core "Bin quantile" "bin quantile val=1"
reg "bin quantile val=10 last" round-2 transform.bin core "Bin quantile" "bin quantile val=10 last"
reg "bin same values" round-2 transform.bin core "Bin same values" "bin same values"
reg "cmp tolerance modified" round-2 compare core "Compare tolerance" "cmp tolerance modified"
reg "cmp tolerance unchanged" round-2 compare core "Compare tolerance" "cmp tolerance unchanged"
reg "cmp tolerance mod key" round-2 compare core "Compare tolerance" "cmp tolerance mod key"
reg "cmp ignore modified" round-2 compare core "Compare ignore" "cmp ignore modified"
reg "cmp ignore unchanged" round-2 compare core "Compare ignore" "cmp ignore unchanged"
reg "cmp ignore diff no updated" round-2 compare core "Compare ignore" "cmp ignore diff no updated"
reg "cmp ignore diff has score" round-2 compare core "Compare ignore" "cmp ignore diff has score"
reg "cmp ignore invalid exit" round-2 compare error "Compare ignore invalid" "cmp ignore invalid exit"
reg "cmp ignore invalid msg" round-2 compare error "Compare ignore invalid" "cmp ignore invalid msg"
reg "hist verify bin0" round-2 profile core "Profile histogram bin counts" "hist verify bin0"
reg "hist verify bin1" round-2 profile core "Profile histogram bin counts" "hist verify bin1"
reg "hist verify bin9" round-2 profile core "Profile histogram bin counts" "hist verify bin9"
reg "hist verify bin5" round-2 profile core "Profile histogram bin counts" "hist verify bin5"
reg "encode empty header" round-2 transform.encode boundary "Encode onehot empty" "encode empty header"
reg "encode empty row2 all zero" round-2 transform.encode boundary "Encode onehot empty" "encode empty row2 all zero"
reg "rollup avg header" round-2 transform.rollup core "Rollup avg" "rollup avg header"
reg "rollup avg Eng" round-2 transform.rollup core "Rollup avg" "rollup avg Eng"
reg "rollup avg Sales" round-2 transform.rollup core "Rollup avg" "rollup avg Sales"
reg "rollup avg grand" round-2 transform.rollup core "Rollup avg" "rollup avg grand"
reg "fill extrap: row1 upper anchor" round-1 transform.fill boundary "Fill linear boundary extrapolation" "fill extrap: row1 upper anchor"
reg "fill extrap: row2 upper anchor" round-1 transform.fill boundary "Fill linear boundary extrapolation" "fill extrap: row2 upper anchor"
reg "fill extrap: row4 interpolated" round-1 transform.fill boundary "Fill linear boundary extrapolation" "fill extrap: row4 interpolated"
reg "fill extrap: row6 lower anchor" round-1 transform.fill boundary "Fill linear boundary extrapolation" "fill extrap: row6 lower anchor"
reg "fill extrap: row7 lower anchor" round-1 transform.fill boundary "Fill linear boundary extrapolation" "fill extrap: row7 lower anchor"
reg "profile p05=1.45" round-2 profile core "Profile p05 and p95" "profile p05=1.45"
reg "profile p95=9.55" round-2 profile core "Profile p05 and p95" "profile p95=9.55"
reg "profile p25 still correct" round-2 profile core "Profile p05 and p95" "profile p25 still correct"
reg "profile p75 still correct" round-2 profile core "Profile p05 and p95" "profile p75 still correct"
reg "drift schema: exit code 0" round-3 drift core "Drift schema" "drift schema: exit code 0"
reg "drift schema: total_drifts=2" round-3 drift core "Drift schema" "drift schema: total_drifts=2"
reg "drift schema: schema_drifts=2" round-3 drift core "Drift schema" "drift schema: schema_drifts=2"
reg "drift schema: first drift col=age" round-3 drift core "Drift schema" "drift schema: first drift col=age"
reg "drift schema: first drift type=column_removed" round-3 drift core "Drift schema" "drift schema: first drift type=column_removed"
reg "drift schema: second drift col=name" round-3 drift core "Drift schema" "drift schema: second drift col=name"
reg "drift schema: second drift type=column_added" round-3 drift core "Drift schema" "drift schema: second drift type=column_added"
reg "drift dist: total_drifts=2" round-3 drift core "Drift distribution" "drift dist: total_drifts=2"
reg "drift dist: distribution_drifts=2" round-3 drift core "Drift distribution" "drift dist: distribution_drifts=2"
reg "drift dist: first=mean_shift" round-3 drift core "Drift distribution" "drift dist: first=mean_shift"
reg "drift dist: second=range_expansion" round-3 drift core "Drift distribution" "drift dist: second=range_expansion"
reg "drift dist: mean shift detail" round-3 drift core "Drift distribution" "drift dist: mean shift detail"
reg "drift nodrift: total_drifts=0" round-3 drift core "Drift no drift" "drift nodrift: total_drifts=0"
reg "drift nodrift: drifts empty" round-3 drift core "Drift no drift" "drift nodrift: drifts empty"
reg "drift error: missing baseline exit=1" round-1 error-handling error "Drift error" "drift error: missing baseline exit=1"
reg "resample over: 4 data rows" round-1 transform.sample core "Resample oversample" "resample over: 4 data rows"
reg "resample over: row1=A,1" round-1 transform.sample core "Resample oversample" "resample over: row1=A,1"
reg "resample over: row2=A,2" round-1 transform.sample core "Resample oversample" "resample over: row2=A,2"
reg "resample over: row3=B,3" round-1 transform.sample core "Resample oversample" "resample over: row3=B,3"
reg "resample over: row4=B,3 (copy)" round-1 transform.sample core "Resample oversample" "resample over: row4=B,3 (copy)"
reg "resample under: 2 data rows" round-1 transform.sample core "Resample undersample" "resample under: 2 data rows"
reg "resample under: header" round-1 transform.sample core "Resample undersample" "resample under: header"
reg "resample under: last row=B,4" round-1 transform.sample core "Resample undersample" "resample under: last row=B,4"
reg "watermark: header" round-3 transform.watermark core "Watermark basic" "watermark: header"
reg "watermark: wm length=16" round-3 transform.watermark core "Watermark basic" "watermark: wm length=16"
reg "watermark: wm is hex" round-3 transform.watermark core "Watermark basic" "watermark: wm is hex"
reg "watermark det: same input same output" round-1 determinism integration "Watermark determinism" "watermark det: same input same output"
reg "pipeline drift: exit code 0" round-1 pipeline integration "Pipeline drift step" "pipeline drift: exit code 0"
reg "pipeline drift: no drifts" round-1 pipeline integration "Pipeline drift step" "pipeline drift: no drifts"
reg "drift type changed: drift_type=type_changed" round-3 drift core "Drift type changed" "drift type changed: drift_type=type_changed"
reg "drift type changed: detail" round-3 drift core "Drift type changed" "drift type changed: detail"
reg "drift null+uniq: total_drifts=2" round-3 drift core "Drift null rate and unique ratio" "drift null+uniq: total_drifts=2"
reg "drift null+uniq: first=null_rate_change" round-3 drift core "Drift null rate and unique ratio" "drift null+uniq: first=null_rate_change"
reg "drift null+uniq: second=unique_ratio_change" round-3 drift core "Drift null rate and unique ratio" "drift null+uniq: second=unique_ratio_change"
reg "resample over multi: 9 rows" round-1 transform.sample core "Resample oversample multi" "resample over multi: 9 rows"
reg "resample over multi: row1=A,1" round-1 transform.sample core "Resample oversample multi" "resample over multi: row1=A,1"
reg "resample over multi: row2=A,1 copy" round-1 transform.sample core "Resample oversample multi" "resample over multi: row2=A,1 copy"
reg "resample over multi: row3=A,1 copy2" round-1 transform.sample core "Resample oversample multi" "resample over multi: row3=A,1 copy2"
reg "resample over multi: row4=B,4" round-1 transform.sample core "Resample oversample multi" "resample over multi: row4=B,4"
reg "resample error: exit code 1" round-1 transform.sample error "Resample error" "resample error: exit code 1"
reg "watermark error: exit code 1" round-1 error-handling error "Watermark error" "watermark error: exit code 1"
reg "drift thresh: low thresh has drifts" round-3 drift core "Drift custom threshold" "drift thresh: low thresh has drifts"
reg "drift thresh: high thresh no drifts" round-3 drift core "Drift custom threshold" "drift thresh: high thresh no drifts"
reg "fill no anchors: row1 empty" round-1 transform.fill core "Fill linear no anchors" "fill no anchors: row1 empty"
reg "fill no anchors: row3 empty" round-1 transform.fill core "Fill linear no anchors" "fill no anchors: row3 empty"
reg "validate type: exit code 0" round-4 validate core "Validate type check" "validate type: exit code 0"
reg "validate type: valid is False" round-4 validate core "Validate type check" "validate type: valid is False"
reg "validate type: violation rule is type" round-4 validate core "Validate type check" "validate type: violation rule is type"
reg "validate type: violation value is abc" round-4 validate core "Validate type check" "validate type: violation value is abc"
reg "validate type: violation message" round-4 validate core "Validate type check" "validate type: violation message"
reg "validate type: violation row is 2" round-4 validate core "Validate type check" "validate type: violation row is 2"
reg "validate type: total violations is 1" round-4 validate core "Validate type check" "validate type: total violations is 1"
reg "validate required: valid is False" round-4 validate core "Validate required" "validate required: valid is False"
reg "validate required: violation rule is required" round-4 validate core "Validate required" "validate required: violation rule is required"
reg "validate required: violation value is None" round-4 validate core "Validate required" "validate required: violation value is None"
reg "validate required: message is value is required" round-4 validate core "Validate required" "validate required: message is value is required"
reg "validate required: violation row is 2" round-4 validate core "Validate required" "validate required: violation row is 2"
reg "validate minmax: valid is False" round-4 validate core "Validate min max" "validate minmax: valid is False"
reg "validate minmax: total violations is 2" round-4 validate core "Validate min max" "validate minmax: total violations is 2"
reg "validate minmax: first violation rule is min" round-4 validate core "Validate min max" "validate minmax: first violation rule is min"
reg "validate minmax: first violation message" round-4 validate core "Validate min max" "validate minmax: first violation message"
reg "validate minmax: first violation row is 2" round-4 validate core "Validate min max" "validate minmax: first violation row is 2"
reg "validate minmax: second violation rule is max" round-4 validate core "Validate min max" "validate minmax: second violation rule is max"
reg "validate minmax: second violation message" round-4 validate core "Validate min max" "validate minmax: second violation message"
reg "validate minmax: second violation row is 4" round-4 validate core "Validate min max" "validate minmax: second violation row is 4"
reg "validate pattern: valid is False" round-4 validate core "Validate pattern" "validate pattern: valid is False"
reg "validate pattern: total violations is 1" round-4 validate core "Validate pattern" "validate pattern: total violations is 1"
reg "validate pattern: violation rule is pattern" round-4 validate core "Validate pattern" "validate pattern: violation rule is pattern"
reg "validate pattern: violation value is hello" round-4 validate core "Validate pattern" "validate pattern: violation value is hello"
reg "validate pattern: violation message" round-4 validate core "Validate pattern" "validate pattern: violation message"
reg "validate pattern: violation row is 2" round-4 validate core "Validate pattern" "validate pattern: violation row is 2"
reg "validate enum: valid is False" round-4 validate core "Validate enum" "validate enum: valid is False"
reg "validate enum: total violations is 1" round-4 validate core "Validate enum" "validate enum: total violations is 1"
reg "validate enum: violation rule is enum" round-4 validate core "Validate enum" "validate enum: violation rule is enum"
reg "validate enum: violation value is D" round-4 validate core "Validate enum" "validate enum: violation value is D"
reg "validate enum: violation message" round-4 validate core "Validate enum" "validate enum: violation message"
reg "validate enum: violation row is 3" round-4 validate core "Validate enum" "validate enum: violation row is 3"
reg "validate unique: valid is False" round-4 validate core "Validate unique" "validate unique: valid is False"
reg "validate unique: total violations is 1" round-4 validate core "Validate unique" "validate unique: total violations is 1"
reg "validate unique: violation rule is unique" round-4 validate core "Validate unique" "validate unique: violation rule is unique"
reg "validate unique: violation value" round-4 validate core "Validate unique" "validate unique: violation value"
reg "validate unique: violation row is None" round-4 validate core "Validate unique" "validate unique: violation row is None"
reg "validate unique: violation message" round-4 validate core "Validate unique" "validate unique: violation message"
reg "validate colmissing: valid is False" round-4 validate error "Validate column missing" "validate colmissing: valid is False"
reg "validate colmissing: total violations is 1" round-4 validate error "Validate column missing" "validate colmissing: total violations is 1"
reg "validate colmissing: violation rule is column_missing" round-4 validate error "Validate column missing" "validate colmissing: violation rule is column_missing"
reg "validate colmissing: violation row is None" round-4 validate error "Validate column missing" "validate colmissing: violation row is None"
reg "validate colmissing: violation message" round-4 validate error "Validate column missing" "validate colmissing: violation message"
reg "validate colmissing: columns_checked is 1" round-4 validate error "Validate column missing" "validate colmissing: columns_checked is 1"
reg "validate strict: valid is False" round-4 validate core "Validate strict mode" "validate strict: valid is False"
reg "validate strict: total violations is 1" round-4 validate core "Validate strict mode" "validate strict: total violations is 1"
reg "validate strict: violation rule is strict" round-4 validate core "Validate strict mode" "validate strict: violation rule is strict"
reg "validate strict: violation column is extra" round-4 validate core "Validate strict mode" "validate strict: violation column is extra"
reg "validate strict: violation message" round-4 validate core "Validate strict mode" "validate strict: violation message"
reg "validate strict: violation value is None" round-4 validate core "Validate strict mode" "validate strict: violation value is None"
reg "validate valid: valid is True" round-4 validate core "Validate valid file" "validate valid: valid is True"
reg "validate valid: total violations is 0" round-4 validate core "Validate valid file" "validate valid: total violations is 0"
reg "validate valid: rows_checked is 3" round-4 validate core "Validate valid file" "validate valid: rows_checked is 3"
reg "validate valid: columns_checked is 3" round-4 validate core "Validate valid file" "validate valid: columns_checked is 3"
reg "validate valid: violations array is empty" round-4 validate core "Validate valid file" "validate valid: violations array is empty"
reg "validate missing input: exit code 1" round-4 validate error "Validate missing input" "validate missing input: exit code 1"
reg "validate missing input: error message" round-4 validate error "Validate missing input" "validate missing input: error message"
reg "validate invalid schema: exit code 1" round-4 validate error "Validate invalid schema" "validate invalid schema: exit code 1"
reg "validate invalid schema: error mentions invalid schema" round-4 validate error "Validate invalid schema" "validate invalid schema: error mentions invalid schema"
reg "validate ordering: valid is False" round-4 validate core "Validate violation ordering" "validate ordering: valid is False"
reg "validate ordering: total violations is 4" round-4 validate core "Validate violation ordering" "validate ordering: total violations is 4"
reg "validate ordering: v0 column is age" round-4 validate core "Validate violation ordering" "validate ordering: v0 column is age"
reg "validate ordering: v0 rule is type" round-4 validate core "Validate violation ordering" "validate ordering: v0 rule is type"
reg "validate ordering: v1 column is age" round-4 validate core "Validate violation ordering" "validate ordering: v1 column is age"
reg "validate ordering: v1 rule is min" round-4 validate core "Validate violation ordering" "validate ordering: v1 rule is min"
reg "validate ordering: v2 column is age" round-4 validate core "Validate violation ordering" "validate ordering: v2 column is age"
reg "validate ordering: v2 rule is max" round-4 validate core "Validate violation ordering" "validate ordering: v2 rule is max"
reg "validate ordering: v3 column is name" round-4 validate core "Validate violation ordering" "validate ordering: v3 column is name"
reg "validate ordering: v3 rule is required" round-4 validate core "Validate violation ordering" "validate ordering: v3 rule is required"
reg "crossjoin basic: header is a,b" round-4 transform.crossjoin integration "Crossjoin basic" "crossjoin basic: header is a,b"
reg "crossjoin basic: row count is 4" round-4 transform.crossjoin integration "Crossjoin basic" "crossjoin basic: row count is 4"
reg "crossjoin basic: row 1 is 1,3" round-4 transform.crossjoin integration "Crossjoin basic" "crossjoin basic: row 1 is 1,3"
reg "crossjoin basic: row 2 is 1,4" round-4 transform.crossjoin integration "Crossjoin basic" "crossjoin basic: row 2 is 1,4"
reg "crossjoin basic: row 3 is 2,3" round-4 transform.crossjoin integration "Crossjoin basic" "crossjoin basic: row 3 is 2,3"
reg "crossjoin basic: row 4 is 2,4" round-4 transform.crossjoin integration "Crossjoin basic" "crossjoin basic: row 4 is 2,4"
reg "crossjoin cols: header is a,c" round-4 transform.crossjoin integration "Crossjoin with columns" "crossjoin cols: header is a,c"
reg "crossjoin cols: row count is 2" round-4 transform.crossjoin integration "Crossjoin with columns" "crossjoin cols: row count is 2"
reg "crossjoin cols: row 1 is 1,4" round-4 transform.crossjoin integration "Crossjoin with columns" "crossjoin cols: row 1 is 1,4"
reg "crossjoin cols: row 2 is 1,6" round-4 transform.crossjoin integration "Crossjoin with columns" "crossjoin cols: row 2 is 1,6"
reg "crossjoin fnf: exit code 1" round-4 transform.crossjoin error "Crossjoin file not found" "crossjoin fnf: exit code 1"
reg "crossjoin fnf: error message" round-4 transform.crossjoin error "Crossjoin file not found" "crossjoin fnf: error message"
reg "crossjoin colnf: exit code 1" round-4 transform.crossjoin error "Crossjoin column not found" "crossjoin colnf: exit code 1"
reg "crossjoin colnf: error about column" round-4 transform.crossjoin error "Crossjoin column not found" "crossjoin colnf: error about column"
reg "checkpoint hash: header is a,b,ckpt" round-2 transform.hash core "Checkpoint row_hash" "checkpoint hash: header is a,b,ckpt"
reg "checkpoint hash: ckpt1 length is 8" round-2 transform.hash core "Checkpoint row_hash" "checkpoint hash: ckpt1 length is 8"
reg "checkpoint hash: ckpt1 is hex" round-2 transform.hash core "Checkpoint row_hash" "checkpoint hash: ckpt1 is hex"
reg "checkpoint hash: ckpt2 length is 8" round-2 transform.hash core "Checkpoint row_hash" "checkpoint hash: ckpt2 length is 8"
reg "checkpoint hash: deterministic same hash" round-2 transform.hash core "Checkpoint row_hash" "checkpoint hash: deterministic same hash"
reg "checkpoint rownum: header is x,rn" round-4 transform.checkpoint core "Checkpoint row_number" "checkpoint rownum: header is x,rn"
reg "checkpoint rownum: row 1 rn=1" round-4 transform.checkpoint core "Checkpoint row_number" "checkpoint rownum: row 1 rn=1"
reg "checkpoint rownum: row 2 rn=2" round-4 transform.checkpoint core "Checkpoint row_number" "checkpoint rownum: row 2 rn=2"
reg "checkpoint rownum: row 3 rn=3" round-4 transform.checkpoint core "Checkpoint row_number" "checkpoint rownum: row 3 rn=3"
reg "pipeline validate r4: exit code 0" round-1 pipeline integration "Pipeline validate step" "pipeline validate r4: exit code 0"
reg "pipeline validate r4: report file exists" round-1 pipeline integration "Pipeline validate step" "pipeline validate r4: report file exists"
reg "pipeline validate r4: valid is False" round-1 pipeline integration "Pipeline validate step" "pipeline validate r4: valid is False"
reg "pipeline validate r4: has 1 violation" round-1 pipeline integration "Pipeline validate step" "pipeline validate r4: has 1 violation"
reg "pipeline validate r4: violation rule is type" round-1 pipeline integration "Pipeline validate step" "pipeline validate r4: violation rule is type"
reg "validate float: valid is False" round-4 validate core "Validate float type check" "validate float: valid is False"
reg "validate float: total violations is 1" round-4 validate core "Validate float type check" "validate float: total violations is 1"
reg "validate float: violation rule is type" round-4 validate core "Validate float type check" "validate float: violation rule is type"
reg "validate float: violation row is 3" round-4 validate core "Validate float type check" "validate float: violation row is 3"
reg "validate float: violation value is abc" round-4 validate core "Validate float type check" "validate float: violation value is abc"
reg "validate float: violation message" round-4 validate core "Validate float type check" "validate float: violation message"
reg "lineage basic: exit code 0" round-5 lineage integration "Lineage basic" "lineage basic: exit code 0"
reg "lineage basic: node count is 4" round-5 lineage integration "Lineage basic" "lineage basic: node count is 4"
reg "lineage basic: edge count is 3" round-5 lineage integration "Lineage basic" "lineage basic: edge count is 3"
reg "lineage basic: step count is 2" round-5 lineage integration "Lineage basic" "lineage basic: step count is 2"
reg "lineage basic: first node is clean.csv" round-5 lineage integration "Lineage basic" "lineage basic: first node is clean.csv"
reg "lineage basic: clean.csv produced_by step 1" round-5 lineage integration "Lineage basic" "lineage basic: clean.csv produced_by step 1"
reg "lineage basic: data.csv produced_by is null" round-5 lineage integration "Lineage basic" "lineage basic: data.csv produced_by is null"
reg "lineage basic: step 1 type is ingest" round-5 lineage integration "Lineage basic" "lineage basic: step 1 type is ingest"
reg "lineage basic: step 2 inputs" round-5 lineage integration "Lineage basic" "lineage basic: step 2 inputs"
reg "lineage profile: node count is 5" round-2 profile integration "Lineage with profile" "lineage profile: node count is 5"
reg "lineage profile: edge count is 4" round-2 profile integration "Lineage with profile" "lineage profile: edge count is 4"
reg "lineage profile: step count is 3" round-2 profile integration "Lineage with profile" "lineage profile: step count is 3"
reg "lineage profile: profile.json produced_by step 3" round-2 profile integration "Lineage with profile" "lineage profile: profile.json produced_by step 3"
reg "lineage profile: step 3 output is profile.json" round-2 profile integration "Lineage with profile" "lineage profile: step 3 output is profile.json"
reg "lineage verify: edge count is 1" round-1 verify integration "Lineage verify step" "lineage verify: edge count is 1"
reg "lineage verify: step 2 output is None" round-1 verify integration "Lineage verify step" "lineage verify: step 2 output is None"
reg "lineage verify: step 2 inputs are file and checksum" round-1 verify integration "Lineage verify step" "lineage verify: step 2 inputs are file and checksum"
reg "lineage file not found: exit code 1" round-5 lineage error "Lineage file not found" "lineage file not found: exit code 1"
reg "lineage file not found: error message" round-5 lineage error "Lineage file not found" "lineage file not found: error message"
reg "lineage invalid JSON: exit code 1" round-5 lineage error "Lineage invalid JSON" "lineage invalid JSON: exit code 1"
reg "lineage invalid JSON: error message" round-5 lineage error "Lineage invalid JSON" "lineage invalid JSON: error message"
reg "blake2b manifest: has blake2b field" round-1 manifest integration "BLAKE2b manifest" "blake2b manifest: has blake2b field"
reg "blake2b manifest: checksum is 64 hex chars" round-1 manifest integration "BLAKE2b manifest" "blake2b manifest: checksum is 64 hex chars"
reg "blake2b manifest: no sha256 field" round-1 manifest integration "BLAKE2b manifest" "blake2b manifest: no sha256 field"
reg "blake2b manifest: checksum matches computed" round-1 manifest integration "BLAKE2b manifest" "blake2b manifest: checksum matches computed"
reg "blake2b verify: correct checksum passes" round-1 verify core "BLAKE2b verify" "blake2b verify: correct checksum passes"
reg "blake2b verify: prints VERIFIED" round-1 verify core "BLAKE2b verify" "blake2b verify: prints VERIFIED"
reg "blake2b verify: sha256 checksum fails" round-1 verify core "BLAKE2b verify" "blake2b verify: sha256 checksum fails"
reg "blake2b verify: sha256 gives MISMATCH" round-1 verify core "BLAKE2b verify" "blake2b verify: sha256 gives MISMATCH"
reg "no sidecar: output file exists" round-1 determinism core "No .sha256 sidecar" "no sidecar: output file exists"
reg "no sidecar: .sha256 not created after ingest" round-1 determinism core "No .sha256 sidecar" "no sidecar: .sha256 not created after ingest"
reg "pipeline lineage step: exit code 0" round-1 pipeline integration "Pipeline lineage step" "pipeline lineage step: exit code 0"
reg "pipeline lineage step: PIPELINE OK" round-1 pipeline integration "Pipeline lineage step" "pipeline lineage step: PIPELINE OK"
reg "pipeline lineage step: lineage has nodes" round-1 pipeline integration "Pipeline lineage step" "pipeline lineage step: lineage has nodes"
reg "pipeline lineage step: lineage file created" round-1 pipeline integration "Pipeline lineage step" "pipeline lineage step: lineage file created"
reg "lineage edge sort: first edge from a_recipe.json" round-5 lineage integration "Lineage edge sorting" "lineage edge sort: first edge from a_recipe.json"
reg "lineage edge sort: second edge from z_input.csv" round-5 lineage integration "Lineage edge sorting" "lineage edge sort: second edge from z_input.csv"
reg "lineage node type: all nodes are file type" round-5 lineage integration "Lineage node type" "lineage node type: all nodes are file type"
reg "lineage format: 2-space indentation" round-5 lineage integration "Lineage JSON format" "lineage format: 2-space indentation"
reg "lineage format: trailing newline" round-5 lineage integration "Lineage JSON format" "lineage format: trailing newline"
reg "lineage manifest step: inputs is empty" round-1 manifest integration "Lineage manifest step" "lineage manifest step: inputs is empty"
reg "lineage manifest step: output is manifest.json" round-1 manifest integration "Lineage manifest step" "lineage manifest step: output is manifest.json"
reg "lineage manifest step: no edges" round-1 manifest integration "Lineage manifest step" "lineage manifest step: no edges"
reg "lineage manifest step: only 1 node" round-1 manifest integration "Lineage manifest step" "lineage manifest step: only 1 node"
reg "audit basic: exit code 0" round-6 audit core "Audit basic" "audit basic: exit code 0"
reg "audit basic: audit file created" round-6 audit core "Audit basic" "audit basic: audit file created"
reg "audit basic: one entry" round-6 audit core "Audit basic" "audit basic: one entry"
reg "audit basic: command is transform" round-6 audit core "Audit basic" "audit basic: command is transform"
reg "audit basic: success is True" round-6 audit core "Audit basic" "audit basic: success is True"
reg "audit basic: error is None" round-6 audit core "Audit basic" "audit basic: error is None"
reg "audit basic: has timestamp" round-6 audit core "Audit basic" "audit basic: has timestamp"
reg "audit basic: duration_ms is non-negative int" round-6 audit core "Audit basic" "audit basic: duration_ms is non-negative int"
reg "audit sizes: input_size matches file" round-6 audit core "Audit sizes" "audit sizes: input_size matches file"
reg "audit sizes: output_size matches file" round-6 audit core "Audit sizes" "audit sizes: output_size matches file"
reg "audit append: two entries after two commands" round-6 audit core "Audit append" "audit append: two entries after two commands"
reg "audit args: --audit not in args" round-6 audit core "Audit args" "audit args: --audit not in args"
reg "audit args: --input in args" round-6 audit core "Audit args" "audit args: --input in args"
reg "audit failure: exit code 1" round-6 audit error "Audit failure" "audit failure: exit code 1"
reg "audit failure: success is False" round-6 audit error "Audit failure" "audit failure: success is False"
reg "audit failure: error message present" round-6 audit error "Audit failure" "audit failure: error message present"
reg "audit failure: output_size is None" round-6 audit error "Audit failure" "audit failure: output_size is None"
reg "audit manifest: command is manifest" round-1 manifest integration "Audit manifest" "audit manifest: command is manifest"
reg "audit manifest: input_size is None" round-1 manifest integration "Audit manifest" "audit manifest: input_size is None"
reg "audit format: 2-space indentation" round-6 audit core "Audit format" "audit format: 2-space indentation"
reg "audit format: trailing newline" round-6 audit core "Audit format" "audit format: trailing newline"
reg "impute mean: row 2 filled with 20" round-6 transform.impute core "Impute mean" "impute mean: row 2 filled with 20"
reg "impute mean: row 4 filled with 20" round-6 transform.impute core "Impute mean" "impute mean: row 4 filled with 20"
reg "impute mean: row 1 unchanged" round-6 transform.impute core "Impute mean" "impute mean: row 1 unchanged"
reg "impute median: row 2 filled with 20" round-6 transform.impute core "Impute median" "impute median: row 2 filled with 20"
reg "impute mode: row 3 filled with 10" round-6 transform.impute core "Impute mode" "impute mode: row 3 filled with 10"
reg "impute mode tie: row 3 filled with 10" round-6 transform.impute core "Impute mode tie" "impute mode tie: row 3 filled with 10"
reg "impute error: exit code 1" round-1 error-handling error "Impute error" "impute error: exit code 1"
reg "impute error: column not found" round-1 error-handling error "Impute error" "impute error: column not found"
reg "impute noop: row 1 unchanged" round-6 transform.impute core "Impute no-op" "impute noop: row 1 unchanged"
reg "impute noop: row 2 unchanged" round-6 transform.impute core "Impute no-op" "impute noop: row 2 unchanged"
reg "impute noop: row 3 unchanged" round-6 transform.impute core "Impute no-op" "impute noop: row 3 unchanged"
reg "audit verify: command is verify" round-1 verify core "Audit verify" "audit verify: command is verify"
reg "audit verify: output_size is None" round-1 verify core "Audit verify" "audit verify: output_size is None"
reg "impute all empty: exit code 0" round-6 transform.impute boundary "Impute all empty" "impute all empty: exit code 0"
reg "impute all empty: row 1 still empty" round-6 transform.impute boundary "Impute all empty" "impute all empty: row 1 still empty"
reg "temporal diff: exit code 0" round-7 transform.temporal core "Temporal diff" "temporal diff: exit code 0"
reg "temporal diff: header" round-7 transform.temporal core "Temporal diff" "temporal diff: header"
reg "temporal diff: row 1 empty" round-7 transform.temporal core "Temporal diff" "temporal diff: row 1 empty"
reg "temporal diff: row 2 = 10" round-7 transform.temporal core "Temporal diff" "temporal diff: row 2 = 10"
reg "temporal diff: row 3 = -5" round-7 transform.temporal core "Temporal diff" "temporal diff: row 3 = -5"
reg "temporal diff: row 4 = 15" round-7 transform.temporal core "Temporal diff" "temporal diff: row 4 = 15"
reg "temporal cumsum: row 1 = 10" round-7 transform.temporal core "Temporal cumsum" "temporal cumsum: row 1 = 10"
reg "temporal cumsum: row 2 = 30" round-7 transform.temporal core "Temporal cumsum" "temporal cumsum: row 2 = 30"
reg "temporal cumsum: row 3 = 60" round-7 transform.temporal core "Temporal cumsum" "temporal cumsum: row 3 = 60"
reg "temporal pct_change: row 1 empty" round-7 transform.temporal core "Temporal pct_change" "temporal pct_change: row 1 empty"
reg "temporal pct_change: row 2 = 0.5" round-7 transform.temporal core "Temporal pct_change" "temporal pct_change: row 2 = 0.5"
reg "temporal pct_change: row 3 = -0.2" round-7 transform.temporal core "Temporal pct_change" "temporal pct_change: row 3 = -0.2"
reg "temporal pct_change zero: row 2 empty" round-7 transform.temporal core "Temporal pct_change zero" "temporal pct_change zero: row 2 empty"
reg "temporal diff empty: row 2 empty" round-7 transform.temporal boundary "Temporal diff empty" "temporal diff empty: row 2 empty"
reg "temporal diff empty: row 3 empty (reset)" round-7 transform.temporal boundary "Temporal diff empty" "temporal diff empty: row 3 empty (reset)"
reg "temporal cumsum empty: row 1 = 10" round-7 transform.temporal boundary "Temporal cumsum empty" "temporal cumsum empty: row 1 = 10"
reg "temporal cumsum empty: row 2 empty" round-7 transform.temporal boundary "Temporal cumsum empty" "temporal cumsum empty: row 2 empty"
reg "temporal cumsum empty: row 3 = 30" round-7 transform.temporal boundary "Temporal cumsum empty" "temporal cumsum empty: row 3 = 30"
reg "temporal error: exit code 1" round-1 error-handling error "Temporal error" "temporal error: exit code 1"
reg "temporal error: column not found" round-1 error-handling error "Temporal error" "temporal error: column not found"
reg "lineage manifest corrected: 4 nodes" round-1 manifest integration "Lineage manifest corrected" "lineage manifest corrected: 4 nodes"
reg "lineage manifest corrected: no output_dir node" round-1 manifest integration "Lineage manifest corrected" "lineage manifest corrected: no output_dir node"
reg "lineage manifest corrected: 1 edge" round-1 manifest integration "Lineage manifest corrected" "lineage manifest corrected: 1 edge"

# Sanitize free-text field values: collapse whitespace, neutralize any literal
# "status=" so the canonical status= token only ever comes from this script.
_san() { printf '%s' "$1" | tr '\n\r\t' '   ' | sed 's/status=/status:/g' | cut -c1-200; }

# Emit one canonical CASE_RESULT line + per-origin/requirement/type tallies.
# Called by the test helpers after their existing decision; does NOT change it.
_emit_case() {
  local name="$1" status="$2" detail="$3"
  CASE_NUM=$((CASE_NUM + 1))
  local cid; cid=$(printf 'c%03d' "$CASE_NUM")
  local origin="${CASE_ORIGIN[$name]:-round-7}"
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

check_approx() {
  TOTAL=$((TOTAL + 1))
  local desc="$1" expected="$2" actual="$3"
  local ok
  ok=$(python3 -c "
import sys
e,a = float('$expected'), float('$actual')
sys.exit(0 if abs(e - a) <= 1e-9 * max(1, abs(e)) else 1)
" 2>/dev/null && echo "1" || echo "0")
  if [ "$ok" = "1" ]; then
    PASS=$((PASS + 1))
    _emit_case "$desc" success ""
  else
    _emit_case "$desc" fail "expected=$expected actual=$actual"
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

  # Check SHA-256 sidecar file does NOT exist (removed in round 5)
  if [ -f "$DIR/output.csv.sha256" ]; then
    check "basic ingest: no .sha256 sidecar" "0" "1"
  else
    check "basic ingest: no .sha256 sidecar" "0" "0"
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
  skip "basic ingest: no .sha256 sidecar"
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
  # Compute BLAKE2b-256 checksum using python3
  python3 -c "
import hashlib
data = open('$DIR/testfile.txt','rb').read()
h = hashlib.blake2b(data, digest_size=32).hexdigest()
open('$DIR/testfile.blake2b','w').write(h + '\n')
"

  VERIFY_OUT=$($DPIPE verify --file "$DIR/testfile.txt" --checksum "$DIR/testfile.blake2b" 2>&1)
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
    {"type": "transform", "input": "/tmp/test_pipeline_ok/clean.csv", "recipe": "/tmp/test_pipeline_ok/recipe.json", "output": "/tmp/test_pipeline_ok/final.csv"}
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
else
  skip "determinism: two identical runs produce same SHA-256"
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

  # Check BLAKE2b in manifest matches computed
  ACTUAL_BLAKE2B=$(python3 -c "
import hashlib
data = open('$DIR/data.csv','rb').read()
print(hashlib.blake2b(data, digest_size=32).hexdigest())
" 2>/dev/null)
  M_BLAKE2B=$(python3 -c "import json; m=json.load(open('$DIR/manifest.json')); print(m['files'][0]['blake2b'])" 2>/dev/null)
  check "manifest detail: BLAKE2b matches" "$ACTUAL_BLAKE2B" "$M_BLAKE2B"
else
  skip "manifest detail: rows count is 3"
  skip "manifest detail: size_bytes matches"
  skip "manifest detail: BLAKE2b matches"
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
# 45. Transform no longer writes .sha256 sidecar (round 5 change)
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
    check "transform: no .sha256 sidecar produced" "0" "1"
  else
    check "transform: no .sha256 sidecar produced" "0" "0"
  fi
else
  skip "transform: no .sha256 sidecar produced"
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
# 93. Profile command - integer column
# =============================================================================
echo ""
echo "=== 93. Profile command - integer column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_profile_int
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,10
2,20
3,30
4,40
5,50
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  if [ -f "$DIR/profile.json" ]; then
    check "profile int: output file exists" "1" "1"
  else
    check "profile int: output file exists" "1" "0"
  fi

  ROW_COUNT=$(jq '.row_count' "$DIR/profile.json" 2>/dev/null)
  check "profile int: row_count" "5" "$ROW_COUNT"

  COL_TYPE=$(jq -r '.columns[0].type' "$DIR/profile.json" 2>/dev/null)
  check "profile int: id column type" "int" "$COL_TYPE"

  COL_COUNT=$(jq '.columns[0].count' "$DIR/profile.json" 2>/dev/null)
  check "profile int: id count" "5" "$COL_COUNT"

  COL_UNIQUE=$(jq '.columns[0].unique' "$DIR/profile.json" 2>/dev/null)
  check "profile int: id unique" "5" "$COL_UNIQUE"

  COL_NULL=$(jq '.columns[0].null_count' "$DIR/profile.json" 2>/dev/null)
  check "profile int: id null_count" "0" "$COL_NULL"

  COL_MIN=$(jq '.columns[0].min' "$DIR/profile.json" 2>/dev/null)
  check "profile int: id min" "1" "$COL_MIN"

  COL_MAX=$(jq '.columns[0].max' "$DIR/profile.json" 2>/dev/null)
  check "profile int: id max" "5" "$COL_MAX"

  COL_MEAN=$(jq '.columns[0].mean' "$DIR/profile.json" 2>/dev/null)
  check "profile int: id mean" "3" "$COL_MEAN"

  # value column: 10,20,30,40,50 -> mean=30, median=30
  VAL_MEAN=$(jq '.columns[1].mean' "$DIR/profile.json" 2>/dev/null)
  check "profile int: value mean" "30" "$VAL_MEAN"

  VAL_MEDIAN=$(jq '.columns[1].median' "$DIR/profile.json" 2>/dev/null)
  check "profile int: value median" "30" "$VAL_MEDIAN"

  VAL_MIN=$(jq '.columns[1].min' "$DIR/profile.json" 2>/dev/null)
  check "profile int: value min" "10" "$VAL_MIN"

  VAL_MAX=$(jq '.columns[1].max' "$DIR/profile.json" 2>/dev/null)
  check "profile int: value max" "50" "$VAL_MAX"
else
  skip "profile int: output file exists"
  skip "profile int: row_count"
  skip "profile int: id column type"
  skip "profile int: id count"
  skip "profile int: id unique"
  skip "profile int: id null_count"
  skip "profile int: id min"
  skip "profile int: id max"
  skip "profile int: id mean"
  skip "profile int: value mean"
  skip "profile int: value median"
  skip "profile int: value min"
  skip "profile int: value max"
fi

# =============================================================================
# 94. Profile command - float column
# =============================================================================
echo ""
echo "=== 94. Profile command - float column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_profile_float
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,score
1,1.5
2,2.5
3,3.5
4,4.5
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  SCORE_TYPE=$(jq -r '.columns[1].type' "$DIR/profile.json" 2>/dev/null)
  check "profile float: score type" "float" "$SCORE_TYPE"

  SCORE_MIN=$(jq '.columns[1].min' "$DIR/profile.json" 2>/dev/null)
  check "profile float: score min" "1.5" "$SCORE_MIN"

  SCORE_MAX=$(jq '.columns[1].max' "$DIR/profile.json" 2>/dev/null)
  check "profile float: score max" "4.5" "$SCORE_MAX"

  SCORE_MEAN=$(jq '.columns[1].mean' "$DIR/profile.json" 2>/dev/null)
  check "profile float: score mean" "3" "$SCORE_MEAN"

  # median: n=4, idx=50/100*3=1.5, values=[1.5,2.5,3.5,4.5], result=2.5+0.5*1=3
  SCORE_MEDIAN=$(jq '.columns[1].median' "$DIR/profile.json" 2>/dev/null)
  check "profile float: score median" "3" "$SCORE_MEDIAN"

  # p25: idx=25/100*3=0.75, values[0]+0.75*(values[1]-values[0])=1.5+0.75*1=2.25
  SCORE_P25=$(jq '.columns[1].p25' "$DIR/profile.json" 2>/dev/null)
  check "profile float: score p25" "2.25" "$SCORE_P25"

  # p75: idx=75/100*3=2.25, values[2]+0.25*(values[3]-values[2])=3.5+0.25*1=3.75
  SCORE_P75=$(jq '.columns[1].p75' "$DIR/profile.json" 2>/dev/null)
  check "profile float: score p75" "3.75" "$SCORE_P75"
else
  skip "profile float: score type"
  skip "profile float: score min"
  skip "profile float: score max"
  skip "profile float: score mean"
  skip "profile float: score median"
  skip "profile float: score p25"
  skip "profile float: score p75"
fi

# =============================================================================
# 95. Profile command - string column
# =============================================================================
echo ""
echo "=== 95. Profile command - string column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_profile_string
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,label
1,Alpha
2,Beta
3,Alpha
4,Gamma
5,Alpha
6,Beta
7,
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  LABEL_TYPE=$(jq -r '.columns[1].type' "$DIR/profile.json" 2>/dev/null)
  check "profile string: label type" "string" "$LABEL_TYPE"

  LABEL_COUNT=$(jq '.columns[1].count' "$DIR/profile.json" 2>/dev/null)
  check "profile string: label count" "6" "$LABEL_COUNT"

  LABEL_NULL=$(jq '.columns[1].null_count' "$DIR/profile.json" 2>/dev/null)
  check "profile string: label null_count" "1" "$LABEL_NULL"

  LABEL_UNIQUE=$(jq '.columns[1].unique' "$DIR/profile.json" 2>/dev/null)
  check "profile string: label unique" "3" "$LABEL_UNIQUE"

  LABEL_MINLEN=$(jq '.columns[1].min_length' "$DIR/profile.json" 2>/dev/null)
  check "profile string: label min_length" "4" "$LABEL_MINLEN"

  LABEL_MAXLEN=$(jq '.columns[1].max_length' "$DIR/profile.json" 2>/dev/null)
  check "profile string: label max_length" "5" "$LABEL_MAXLEN"

  # most_common: Alpha(3), Beta(2), Gamma(1) - sorted by count desc
  MC_FIRST_VAL=$(jq -r '.columns[1].most_common[0].value' "$DIR/profile.json" 2>/dev/null)
  MC_FIRST_CNT=$(jq '.columns[1].most_common[0].count' "$DIR/profile.json" 2>/dev/null)
  check "profile string: most_common[0] value" "Alpha" "$MC_FIRST_VAL"
  check "profile string: most_common[0] count" "3" "$MC_FIRST_CNT"

  MC_SECOND_VAL=$(jq -r '.columns[1].most_common[1].value' "$DIR/profile.json" 2>/dev/null)
  check "profile string: most_common[1] value" "Beta" "$MC_SECOND_VAL"

  MC_LEN=$(jq '.columns[1].most_common | length' "$DIR/profile.json" 2>/dev/null)
  check "profile string: most_common length" "3" "$MC_LEN"
else
  skip "profile string: label type"
  skip "profile string: label count"
  skip "profile string: label null_count"
  skip "profile string: label unique"
  skip "profile string: label min_length"
  skip "profile string: label max_length"
  skip "profile string: most_common[0] value"
  skip "profile string: most_common[0] count"
  skip "profile string: most_common[1] value"
  skip "profile string: most_common length"
fi

# =============================================================================
# 96. Profile command - datetime column
# =============================================================================
echo ""
echo "=== 96. Profile command - datetime column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_profile_datetime
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,ts
1,2024-01-15T00:00:00Z
2,2024-03-10T00:00:00Z
3,2024-01-01T00:00:00Z
4,2024-06-20T00:00:00Z
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  TS_TYPE=$(jq -r '.columns[1].type' "$DIR/profile.json" 2>/dev/null)
  check "profile datetime: ts type" "datetime" "$TS_TYPE"

  TS_EARLIEST=$(jq -r '.columns[1].earliest' "$DIR/profile.json" 2>/dev/null)
  check "profile datetime: earliest" "2024-01-01T00:00:00Z" "$TS_EARLIEST"

  TS_LATEST=$(jq -r '.columns[1].latest' "$DIR/profile.json" 2>/dev/null)
  check "profile datetime: latest" "2024-06-20T00:00:00Z" "$TS_LATEST"

  TS_COUNT=$(jq '.columns[1].count' "$DIR/profile.json" 2>/dev/null)
  check "profile datetime: count" "4" "$TS_COUNT"
else
  skip "profile datetime: ts type"
  skip "profile datetime: earliest"
  skip "profile datetime: latest"
  skip "profile datetime: count"
fi

# =============================================================================
# 97. Profile command - empty column
# =============================================================================
echo ""
echo "=== 97. Profile command - empty column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_profile_empty
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,empty_col
1,
2,
3,
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  EMPTY_TYPE=$(jq -r '.columns[1].type' "$DIR/profile.json" 2>/dev/null)
  check "profile empty: type is string" "string" "$EMPTY_TYPE"

  EMPTY_COUNT=$(jq '.columns[1].count' "$DIR/profile.json" 2>/dev/null)
  check "profile empty: count is 0" "0" "$EMPTY_COUNT"

  EMPTY_NULL=$(jq '.columns[1].null_count' "$DIR/profile.json" 2>/dev/null)
  check "profile empty: null_count is 3" "3" "$EMPTY_NULL"

  EMPTY_MINLEN=$(jq '.columns[1].min_length' "$DIR/profile.json" 2>/dev/null)
  check "profile empty: min_length is 0" "0" "$EMPTY_MINLEN"

  EMPTY_MC_LEN=$(jq '.columns[1].most_common | length' "$DIR/profile.json" 2>/dev/null)
  check "profile empty: most_common is empty" "0" "$EMPTY_MC_LEN"
else
  skip "profile empty: type is string"
  skip "profile empty: count is 0"
  skip "profile empty: null_count is 3"
  skip "profile empty: min_length is 0"
  skip "profile empty: most_common is empty"
fi

# =============================================================================
# 98. Profile command - single value column (stddev=0)
# =============================================================================
echo ""
echo "=== 98. Profile command - single value column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_profile_single
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,42
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  VAL_STDDEV=$(jq '.columns[1].stddev' "$DIR/profile.json" 2>/dev/null)
  check "profile single: stddev is 0" "0" "$VAL_STDDEV"

  VAL_MEDIAN=$(jq '.columns[1].median' "$DIR/profile.json" 2>/dev/null)
  check "profile single: median is 42" "42" "$VAL_MEDIAN"

  VAL_P25=$(jq '.columns[1].p25' "$DIR/profile.json" 2>/dev/null)
  check "profile single: p25 is 42" "42" "$VAL_P25"
else
  skip "profile single: stddev is 0"
  skip "profile single: median is 42"
  skip "profile single: p25 is 42"
fi

# =============================================================================
# 99. Profile command - percentile interpolation
# =============================================================================
echo ""
echo "=== 99. Profile command - percentile interpolation ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_profile_pct
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
x
1
2
3
4
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  # n=4, p25: idx=0.75 -> 1+0.75*(2-1)=1.75
  P25=$(jq '.columns[0].p25' "$DIR/profile.json" 2>/dev/null)
  check "profile pct: p25 interpolation" "1.75" "$P25"

  # n=4, p50: idx=1.5 -> 2+0.5*(3-2)=2.5
  MEDIAN=$(jq '.columns[0].median' "$DIR/profile.json" 2>/dev/null)
  check "profile pct: median interpolation" "2.5" "$MEDIAN"

  # n=4, p75: idx=2.25 -> 3+0.25*(4-3)=3.25
  P75=$(jq '.columns[0].p75' "$DIR/profile.json" 2>/dev/null)
  check "profile pct: p75 interpolation" "3.25" "$P75"
else
  skip "profile pct: p25 interpolation"
  skip "profile pct: median interpolation"
  skip "profile pct: p75 interpolation"
fi

# =============================================================================
# 100. Profile command - stddev calculation
# =============================================================================
echo ""
echo "=== 100. Profile command - stddev calculation ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_profile_stddev
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
x
1
2
3
4
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  # mean=2.5, variance=((1-2.5)^2+(2-2.5)^2+(3-2.5)^2+(4-2.5)^2)/4 = 5/4 = 1.25
  # stddev=sqrt(1.25)=1.118033988749895
  STDDEV=$(jq '.columns[0].stddev' "$DIR/profile.json" 2>/dev/null)
  EXPECTED="1.118033988749895"
  CLOSE=$(python3 -c "print('yes' if abs($STDDEV - $EXPECTED) < 1e-10 else 'no')" 2>/dev/null)
  check "profile stddev: population stddev" "yes" "$CLOSE"
else
  skip "profile stddev: population stddev"
fi

# =============================================================================
# 101. Profile command - most_common tiebreaking
# =============================================================================
echo ""
echo "=== 101. Profile command - most_common tiebreaking ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_profile_mc_tie
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
label
Zebra
Alpha
Zebra
Alpha
Middle
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  # Alpha(2) and Zebra(2) tied; Alpha < Zebra lexicographically
  MC0=$(jq -r '.columns[0].most_common[0].value' "$DIR/profile.json" 2>/dev/null)
  check "profile mc tie: first is Alpha" "Alpha" "$MC0"

  MC1=$(jq -r '.columns[0].most_common[1].value' "$DIR/profile.json" 2>/dev/null)
  check "profile mc tie: second is Zebra" "Zebra" "$MC1"

  MC2=$(jq -r '.columns[0].most_common[2].value' "$DIR/profile.json" 2>/dev/null)
  check "profile mc tie: third is Middle" "Middle" "$MC2"
else
  skip "profile mc tie: first is Alpha"
  skip "profile mc tie: second is Zebra"
  skip "profile mc tie: third is Middle"
fi

# =============================================================================
# 102. Profile command - missing file error
# =============================================================================
echo ""
echo "=== 102. Profile command - missing file error ==="
if [ "$BUILD_OK" = "1" ]; then
  ERR=$($DPIPE profile --input /nonexistent.csv --output /tmp/out.json 2>&1)
  EC=$?
  check "profile missing file: exit code 1" "1" "$EC"
  check_contains "profile missing file: error message" "file not found" "$ERR"
else
  skip "profile missing file: exit code 1"
  skip "profile missing file: error message"
fi

# =============================================================================
# 103. Deduplicate transform - keep first
# =============================================================================
echo ""
echo "=== 103. Deduplicate transform - keep first ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_dedup_first
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,name,value
1,Alice,100
2,Bob,200
3,Alice,300
4,Charlie,400
5,Bob,500
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "deduplicate", "columns": ["name"], "keep": "first"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "dedup first: row count is 3" "3" "$ROW_COUNT"

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "dedup first: row 1 is Alice(100)" "1,Alice,100" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "dedup first: row 2 is Bob(200)" "2,Bob,200" "$ROW2"

  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "dedup first: row 3 is Charlie(400)" "4,Charlie,400" "$ROW3"
else
  skip "dedup first: row count is 3"
  skip "dedup first: row 1 is Alice(100)"
  skip "dedup first: row 2 is Bob(200)"
  skip "dedup first: row 3 is Charlie(400)"
fi

# =============================================================================
# 104. Deduplicate transform - keep last
# =============================================================================
echo ""
echo "=== 104. Deduplicate transform - keep last ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_dedup_last
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,name,value
1,Alice,100
2,Bob,200
3,Alice,300
4,Charlie,400
5,Bob,500
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "deduplicate", "columns": ["name"], "keep": "last"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "dedup last: row count is 3" "3" "$ROW_COUNT"

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "dedup last: row 1 is Alice(300)" "3,Alice,300" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "dedup last: row 2 is Charlie(400)" "4,Charlie,400" "$ROW2"

  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "dedup last: row 3 is Bob(500)" "5,Bob,500" "$ROW3"
else
  skip "dedup last: row count is 3"
  skip "dedup last: row 1 is Alice(300)"
  skip "dedup last: row 2 is Charlie(400)"
  skip "dedup last: row 3 is Bob(500)"
fi

# =============================================================================
# 105. Deduplicate transform - all columns (no columns specified)
# =============================================================================
echo ""
echo "=== 105. Deduplicate transform - all columns ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_dedup_all
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
a,b
1,x
2,y
1,x
3,z
2,y
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "deduplicate", "keep": "first"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "dedup all cols: row count is 3" "3" "$ROW_COUNT"

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "dedup all cols: row 1" "1,x" "$ROW1"
else
  skip "dedup all cols: row count is 3"
  skip "dedup all cols: row 1"
fi

# =============================================================================
# 106. Deduplicate transform - missing column error
# =============================================================================
echo ""
echo "=== 106. Deduplicate transform - missing column error ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_dedup_err
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
a,b
1,x
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "deduplicate", "columns": ["nonexistent"], "keep": "first"}]
EOF

  ERR=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>&1)
  EC=$?
  check "dedup missing col: exit code 1" "1" "$EC"
  check_contains "dedup missing col: error mentions column" "column nonexistent not found" "$ERR"
else
  skip "dedup missing col: exit code 1"
  skip "dedup missing col: error mentions column"
fi

# =============================================================================
# 107. Split transform - basic
# =============================================================================
echo ""
echo "=== 107. Split transform - basic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_split_basic
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,full_name,age
1,John Smith,30
2,Jane Doe,25
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "split", "column": "full_name", "delimiter": " ", "names": ["first", "last"]}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv")
  check "split basic: header" "id,first,last,age" "$HEADER"

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "split basic: row 1" "1,John,Smith,30" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "split basic: row 2" "2,Jane,Doe,25" "$ROW2"
else
  skip "split basic: header"
  skip "split basic: row 1"
  skip "split basic: row 2"
fi

# =============================================================================
# 108. Split transform - fewer parts than names
# =============================================================================
echo ""
echo "=== 108. Split transform - fewer parts than names ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_split_fewer
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,data
1,hello
2,world
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "split", "column": "data", "delimiter": "-", "names": ["part1", "part2", "part3"]}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv")
  check "split fewer: header" "id,part1,part2,part3" "$HEADER"

  # "hello" split by "-" = ["hello"], so part1=hello, part2="", part3=""
  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "split fewer: row 1 (no delimiter found)" "1,hello,," "$ROW1"
else
  skip "split fewer: header"
  skip "split fewer: row 1 (no delimiter found)"
fi

# =============================================================================
# 109. Split transform - more parts than names (remainder)
# =============================================================================
echo ""
echo "=== 109. Split transform - more parts than names ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_split_more
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,path
1,a/b/c/d
2,x/y
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "split", "column": "path", "delimiter": "/", "names": ["first", "rest"]}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "split more: row 1 (remainder)" "1,a,b/c/d" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "split more: row 2 (exact)" "2,x,y" "$ROW2"
else
  skip "split more: row 1 (remainder)"
  skip "split more: row 2 (exact)"
fi

# =============================================================================
# 110. Split transform - column position preserved
# =============================================================================
echo ""
echo "=== 110. Split transform - column position preserved ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_split_pos
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
a,b,c
1,x-y,3
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "split", "column": "b", "delimiter": "-", "names": ["b1", "b2"]}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv")
  check "split pos: columns at correct position" "a,b1,b2,c" "$HEADER"

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "split pos: row values" "1,x,y,3" "$ROW1"
else
  skip "split pos: columns at correct position"
  skip "split pos: row values"
fi

# =============================================================================
# 111. Split transform - missing column error
# =============================================================================
echo ""
echo "=== 111. Split transform - missing column error ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_split_err
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
a,b
1,2
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "split", "column": "missing", "delimiter": "-", "names": ["x", "y"]}]
EOF

  ERR=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>&1)
  EC=$?
  check "split missing col: exit code 1" "1" "$EC"
  check_contains "split missing col: error message" "column missing not found" "$ERR"
else
  skip "split missing col: exit code 1"
  skip "split missing col: error message"
fi

# =============================================================================
# 112. Assert transform - pass
# =============================================================================
echo ""
echo "=== 112. Assert transform - pass ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_assert_pass
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,20
3,30
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "assert", "expression": "value > 0", "message": "value must be positive"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null
  EC=$?
  check "assert pass: exit code 0" "0" "$EC"

  ROW_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "assert pass: rows preserved" "3" "$ROW_COUNT"
else
  skip "assert pass: exit code 0"
  skip "assert pass: rows preserved"
fi

# =============================================================================
# 113. Assert transform - fail
# =============================================================================
echo ""
echo "=== 113. Assert transform - fail ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_assert_fail
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,-5
3,20
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "assert", "expression": "value > 0", "message": "value must be positive"}]
EOF

  ERR=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>&1)
  EC=$?
  check "assert fail: exit code 1" "1" "$EC"
  check_contains "assert fail: error mentions row 2" "assertion failed on row 2" "$ERR"
  check_contains "assert fail: error message" "value must be positive" "$ERR"
else
  skip "assert fail: exit code 1"
  skip "assert fail: error mentions row 2"
  skip "assert fail: error message"
fi

# =============================================================================
# 114. Assert transform - complex expression
# =============================================================================
echo ""
echo "=== 114. Assert transform - complex expression ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_assert_complex
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,a,b
1,10,5
2,20,15
3,5,3
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "assert", "expression": "a > b && a < 100", "message": "a must be greater than b and less than 100"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null
  EC=$?
  check "assert complex: all rows pass" "0" "$EC"
else
  skip "assert complex: all rows pass"
fi

# =============================================================================
# 115. Pipeline with profile step
# =============================================================================
echo ""
echo "=== 115. Pipeline with profile step ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pipe_profile
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,10
2,20
3,30
EOF

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "profile", "input": "data.csv", "output": "profile.json"}
  ]
}
EOF

  cd "$DIR"
  OUTPUT=$($DPIPE pipeline --config pipeline.json 2>&1)
  EC=$?
  cd /app
  check "pipeline profile: exit code 0" "0" "$EC"
  check_contains "pipeline profile: OK message" "PIPELINE OK" "$OUTPUT"

  if [ -f "$DIR/profile.json" ]; then
    check "pipeline profile: output file created" "1" "1"
  else
    check "pipeline profile: output file created" "1" "0"
  fi

  ROW_COUNT=$(jq '.row_count' "$DIR/profile.json" 2>/dev/null)
  check "pipeline profile: row_count correct" "3" "$ROW_COUNT"
else
  skip "pipeline profile: exit code 0"
  skip "pipeline profile: OK message"
  skip "pipeline profile: output file created"
  skip "pipeline profile: row_count correct"
fi

# =============================================================================
# 116. Profile type inference - mixed values
# =============================================================================
echo ""
echo "=== 116. Profile type inference - mixed values ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_profile_mixed
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
col
1
2
three
4
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  COL_TYPE=$(jq -r '.columns[0].type' "$DIR/profile.json" 2>/dev/null)
  check "profile mixed: non-int non-float -> string" "string" "$COL_TYPE"
else
  skip "profile mixed: non-int non-float -> string"
fi

# =============================================================================
# 117. Deduplicate then sort chain
# =============================================================================
echo ""
echo "=== 117. Deduplicate then sort chain ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_dedup_sort
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,name
3,Alice
1,Bob
2,Alice
4,Charlie
1,Bob
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[
  {"op": "deduplicate", "columns": ["name"], "keep": "first"},
  {"op": "sort", "column": "id", "order": "asc"}
]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "dedup+sort: first row id=1" "1,Bob" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "dedup+sort: second row id=3" "3,Alice" "$ROW2"

  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "dedup+sort: third row id=4" "4,Charlie" "$ROW3"
else
  skip "dedup+sort: first row id=1"
  skip "dedup+sort: second row id=3"
  skip "dedup+sort: third row id=4"
fi

# =============================================================================
# 118. Split then derive chain
# =============================================================================
echo ""
echo "=== 118. Split then derive chain ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_split_derive
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,coords
1,10-20
2,30-40
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[
  {"op": "split", "column": "coords", "delimiter": "-", "names": ["x", "y"]},
  {"op": "derive", "name": "sum", "expression": "x + y"}
]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv")
  check "split+derive: header" "id,x,y,sum" "$HEADER"

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "split+derive: row 1 sum" "1,10,20,30" "$ROW1"
else
  skip "split+derive: header"
  skip "split+derive: row 1 sum"
fi

# =============================================================================
# 119. Assert then filter chain
# =============================================================================
echo ""
echo "=== 119. Assert then filter chain ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_assert_filter
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,20
3,30
4,40
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[
  {"op": "assert", "expression": "value > 0", "message": "positive"},
  {"op": "filter", "column": "value", "condition": "gt", "threshold": 15}
]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null
  EC=$?
  check "assert+filter: exit code 0" "0" "$EC"

  ROW_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "assert+filter: 3 rows after filter" "3" "$ROW_COUNT"
else
  skip "assert+filter: exit code 0"
  skip "assert+filter: 3 rows after filter"
fi

# =============================================================================
# 120. Profile with nulls in numeric column
# =============================================================================
echo ""
echo "=== 120. Profile with nulls in numeric column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_profile_nullnum
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,10
2,
3,30
4,
5,50
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  VAL_COUNT=$(jq '.columns[1].count' "$DIR/profile.json" 2>/dev/null)
  check "profile nullnum: value count" "3" "$VAL_COUNT"

  VAL_NULL=$(jq '.columns[1].null_count' "$DIR/profile.json" 2>/dev/null)
  check "profile nullnum: value null_count" "2" "$VAL_NULL"

  VAL_MEAN=$(jq '.columns[1].mean' "$DIR/profile.json" 2>/dev/null)
  check "profile nullnum: value mean" "30" "$VAL_MEAN"

  VAL_MEDIAN=$(jq '.columns[1].median' "$DIR/profile.json" 2>/dev/null)
  check "profile nullnum: value median" "30" "$VAL_MEDIAN"
else
  skip "profile nullnum: value count"
  skip "profile nullnum: value null_count"
  skip "profile nullnum: value mean"
  skip "profile nullnum: value median"
fi

# =============================================================================
# 121. Profile correlations: perfect positive
# =============================================================================
echo ""
echo "=== 121. Profile correlations: perfect positive ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_corr_pos
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
a,b
1,2
2,4
3,6
4,8
5,10
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  CORR_LEN=$(jq '.correlations | length' "$DIR/profile.json" 2>/dev/null)
  check "corr positive: pair count" "1" "$CORR_LEN"

  CORR_VAL=$(jq '.correlations[0].correlation' "$DIR/profile.json" 2>/dev/null)
  check "corr positive: r=1" "1" "$CORR_VAL"
else
  skip "corr positive: pair count"
  skip "corr positive: r=1"
fi

# =============================================================================
# 122. Profile correlations: zero stddev
# =============================================================================
echo ""
echo "=== 122. Profile correlations: zero stddev ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_corr_zstd
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
x,y
5,1
5,2
5,3
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  CORR_LEN=$(jq '.correlations | length' "$DIR/profile.json" 2>/dev/null)
  check "corr zero stddev: pair count" "1" "$CORR_LEN"

  CORR_VAL=$(jq '.correlations[0].correlation' "$DIR/profile.json" 2>/dev/null)
  check "corr zero stddev: null" "null" "$CORR_VAL"
else
  skip "corr zero stddev: pair count"
  skip "corr zero stddev: null"
fi

# =============================================================================
# 123. Profile correlations: insufficient pairs
# =============================================================================
echo ""
echo "=== 123. Profile correlations: insufficient pairs ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_corr_insuf
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
a,b
1,
,2
3,
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  CORR_VAL=$(jq '.correlations[0].correlation' "$DIR/profile.json" 2>/dev/null)
  check "corr insufficient: null" "null" "$CORR_VAL"
else
  skip "corr insufficient: null"
fi

# =============================================================================
# 124. Profile correlations: only numeric columns paired
# =============================================================================
echo ""
echo "=== 124. Profile correlations: only numeric ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_corr_numonly
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,name,score
1,Alice,90
2,Bob,80
3,Charlie,70
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  CORR_LEN=$(jq '.correlations | length' "$DIR/profile.json" 2>/dev/null)
  check "corr numonly: pair count" "1" "$CORR_LEN"

  COL_A=$(jq -r '.correlations[0].column_a' "$DIR/profile.json" 2>/dev/null)
  check "corr numonly: column_a" "id" "$COL_A"

  COL_B=$(jq -r '.correlations[0].column_b' "$DIR/profile.json" 2>/dev/null)
  check "corr numonly: column_b" "score" "$COL_B"

  CORR_VAL=$(jq '.correlations[0].correlation' "$DIR/profile.json" 2>/dev/null)
  check "corr numonly: r=-1" "-1" "$CORR_VAL"
else
  skip "corr numonly: pair count"
  skip "corr numonly: column_a"
  skip "corr numonly: column_b"
  skip "corr numonly: r=-1"
fi

# =============================================================================
# 125. Normalize zscore basic
# =============================================================================
echo ""
echo "=== 125. Normalize zscore basic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_norm_zscore
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,0
2,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "normalize", "column": "value", "method": "zscore", "as": "value_z"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv" 2>/dev/null)
  check "norm zscore: header" "id,value,value_z" "$HEADER"

  ROW1=$(tail -n +2 "$DIR/out.csv" | head -1)
  Z1=$(echo "$ROW1" | cut -d',' -f3)
  check_approx "norm zscore: row1 z=-0.7071" "-0.7071067811865475" "$Z1"

  ROW2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  Z2=$(echo "$ROW2" | cut -d',' -f3)
  check_approx "norm zscore: row2 z=0.7071" "0.7071067811865475" "$Z2"
else
  skip "norm zscore: header"
  skip "norm zscore: row1 z=-0.7071"
  skip "norm zscore: row2 z=0.7071"
fi

# =============================================================================
# 126. Normalize minmax basic
# =============================================================================
echo ""
echo "=== 126. Normalize minmax basic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_norm_minmax
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,0
2,5
3,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "normalize", "column": "value", "method": "minmax", "as": "value_n"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(tail -n +2 "$DIR/out.csv" | head -1)
  N1=$(echo "$ROW1" | cut -d',' -f3)
  check "norm minmax: row1=0" "0" "$N1"

  ROW2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  N2=$(echo "$ROW2" | cut -d',' -f3)
  check "norm minmax: row2=0.5" "0.5" "$N2"

  ROW3=$(tail -n +2 "$DIR/out.csv" | sed -n '3p')
  N3=$(echo "$ROW3" | cut -d',' -f3)
  check "norm minmax: row3=1" "1" "$N3"
else
  skip "norm minmax: row1=0"
  skip "norm minmax: row2=0.5"
  skip "norm minmax: row3=1"
fi

# =============================================================================
# 127. Normalize zscore zero stddev
# =============================================================================
echo ""
echo "=== 127. Normalize zscore zero stddev ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_norm_zstd0
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,5
2,5
3,5
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "normalize", "column": "value", "method": "zscore", "as": "value_z"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(tail -n +2 "$DIR/out.csv" | head -1)
  Z1=$(echo "$ROW1" | cut -d',' -f3)
  check "norm zscore zero stddev: row1=0" "0" "$Z1"

  ROW3=$(tail -n +2 "$DIR/out.csv" | sed -n '3p')
  Z3=$(echo "$ROW3" | cut -d',' -f3)
  check "norm zscore zero stddev: row3=0" "0" "$Z3"
else
  skip "norm zscore zero stddev: row1=0"
  skip "norm zscore zero stddev: row3=0"
fi

# =============================================================================
# 128. Normalize minmax all same values
# =============================================================================
echo ""
echo "=== 128. Normalize minmax all same ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_norm_mm_same
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,7
2,7
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "normalize", "column": "value", "method": "minmax", "as": "value_n"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(tail -n +2 "$DIR/out.csv" | head -1)
  N1=$(echo "$ROW1" | cut -d',' -f3)
  check "norm minmax same: row1=0" "0" "$N1"

  ROW2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  N2=$(echo "$ROW2" | cut -d',' -f3)
  check "norm minmax same: row2=0" "0" "$N2"
else
  skip "norm minmax same: row1=0"
  skip "norm minmax same: row2=0"
fi

# =============================================================================
# 129. Normalize with non-numeric and empty values
# =============================================================================
echo ""
echo "=== 129. Normalize non-numeric and empty ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_norm_mixed
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,hello
3,
4,30
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "normalize", "column": "value", "method": "zscore", "as": "value_z"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(tail -n +2 "$DIR/out.csv" | head -1)
  Z1=$(echo "$ROW1" | cut -d',' -f3)
  check_approx "norm mixed: row1 z=-0.7071" "-0.7071067811865475" "$Z1"

  ROW2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  Z2=$(echo "$ROW2" | cut -d',' -f3)
  check "norm mixed: row2 non-numeric empty" "" "$Z2"

  ROW3=$(tail -n +2 "$DIR/out.csv" | sed -n '3p')
  Z3=$(echo "$ROW3" | cut -d',' -f3)
  check "norm mixed: row3 empty stays empty" "" "$Z3"

  ROW4=$(tail -n +2 "$DIR/out.csv" | sed -n '4p')
  Z4=$(echo "$ROW4" | cut -d',' -f3)
  check_approx "norm mixed: row4 z=0.7071" "0.7071067811865475" "$Z4"
else
  skip "norm mixed: row1 z=-0.7071"
  skip "norm mixed: row2 non-numeric empty"
  skip "norm mixed: row3 empty stays empty"
  skip "norm mixed: row4 z=0.7071"
fi

# =============================================================================
# 130. Normalize missing column error
# =============================================================================
echo ""
echo "=== 130. Normalize missing column error ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_norm_err
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "normalize", "column": "nonexistent", "method": "zscore", "as": "norm"}]
EOF

  ERR_OUT=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>&1)
  ERR_EXIT=$?
  check "norm missing col: exit code 1" "1" "$ERR_EXIT"
else
  skip "norm missing col: exit code 1"
fi

# =============================================================================
# 131. Fill linear basic interpolation
# =============================================================================
echo ""
echo "=== 131. Fill linear basic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_fill_linear
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,temperature
1,10
2,
3,
4,40
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "fill", "columns": ["temperature"], "strategy": "linear"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  T2=$(echo "$ROW2" | cut -d',' -f2)
  check "fill linear: row2=20" "20" "$T2"

  ROW3=$(tail -n +2 "$DIR/out.csv" | sed -n '3p')
  T3=$(echo "$ROW3" | cut -d',' -f2)
  check "fill linear: row3=30" "30" "$T3"
else
  skip "fill linear: row2=20"
  skip "fill linear: row3=30"
fi

# =============================================================================
# 132. Fill linear boundaries remain empty
# =============================================================================
echo ""
echo "=== 132. Fill linear boundaries ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_fill_lin_bound
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,
2,10
3,
4,20
5,
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "fill", "columns": ["value"], "strategy": "linear"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(tail -n +2 "$DIR/out.csv" | head -1)
  V1=$(echo "$ROW1" | cut -d',' -f2)
  check "fill linear bound: row1 extrapolated" "10" "$V1"

  ROW3=$(tail -n +2 "$DIR/out.csv" | sed -n '3p')
  V3=$(echo "$ROW3" | cut -d',' -f2)
  check "fill linear bound: row3=15" "15" "$V3"

  ROW5=$(tail -n +2 "$DIR/out.csv" | sed -n '5p')
  V5=$(echo "$ROW5" | cut -d',' -f2)
  check "fill linear bound: row5 extrapolated" "20" "$V5"
else
  skip "fill linear bound: row1 extrapolated"
  skip "fill linear bound: row3=15"
  skip "fill linear bound: row5 extrapolated"
fi

# =============================================================================
# 133. Fill linear non-numeric values skipped
# =============================================================================
echo ""
echo "=== 133. Fill linear non-numeric ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_fill_lin_nonum
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,abc
3,
4,40
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "fill", "columns": ["value"], "strategy": "linear"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  V2=$(echo "$ROW2" | cut -d',' -f2)
  check "fill linear nonum: row2 unchanged abc" "abc" "$V2"

  ROW3=$(tail -n +2 "$DIR/out.csv" | sed -n '3p')
  V3=$(echo "$ROW3" | cut -d',' -f2)
  check "fill linear nonum: row3=30" "30" "$V3"
else
  skip "fill linear nonum: row2 unchanged abc"
  skip "fill linear nonum: row3=30"
fi

# =============================================================================
# 134. Fill linear multiple gaps
# =============================================================================
echo ""
echo "=== 134. Fill linear multiple gaps ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_fill_lin_multi
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
idx,val
1,0
2,
3,
4,
5,
6,50
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "fill", "columns": ["val"], "strategy": "linear"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  V2=$(echo "$ROW2" | cut -d',' -f2)
  check "fill linear multi: row2=10" "10" "$V2"

  ROW3=$(tail -n +2 "$DIR/out.csv" | sed -n '3p')
  V3=$(echo "$ROW3" | cut -d',' -f2)
  check "fill linear multi: row3=20" "20" "$V3"

  ROW4=$(tail -n +2 "$DIR/out.csv" | sed -n '4p')
  V4=$(echo "$ROW4" | cut -d',' -f2)
  check "fill linear multi: row4=30" "30" "$V4"

  ROW5=$(tail -n +2 "$DIR/out.csv" | sed -n '5p')
  V5=$(echo "$ROW5" | cut -d',' -f2)
  check "fill linear multi: row5=40" "40" "$V5"
else
  skip "fill linear multi: row2=10"
  skip "fill linear multi: row3=20"
  skip "fill linear multi: row4=30"
  skip "fill linear multi: row5=40"
fi

# =============================================================================
# 135. Profile negative correlation
# =============================================================================
echo ""
echo "=== 135. Profile negative correlation ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_corr_neg
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
a,b
1,10
2,8
3,6
4,4
5,2
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  CORR_VAL=$(jq '.correlations[0].correlation' "$DIR/profile.json" 2>/dev/null)
  check "corr negative: r=-1" "-1" "$CORR_VAL"
else
  skip "corr negative: r=-1"
fi

# =============================================================================
# 136. Profile three numeric columns
# =============================================================================
echo ""
echo "=== 136. Profile three numeric columns ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_corr_three
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
a,b,c
1,2,3
2,4,6
3,6,9
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  CORR_LEN=$(jq '.correlations | length' "$DIR/profile.json" 2>/dev/null)
  check "corr three cols: 3 pairs" "3" "$CORR_LEN"

  CORR_AB=$(jq '.correlations[0].correlation' "$DIR/profile.json" 2>/dev/null)
  check "corr three cols: ab=1" "1" "$CORR_AB"
else
  skip "corr three cols: 3 pairs"
  skip "corr three cols: ab=1"
fi

# =============================================================================
# 137. Profile correlations with float columns
# =============================================================================
echo ""
echo "=== 137. Profile correlations float columns ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_corr_float
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
x,y
1.5,3.0
2.5,5.0
3.5,7.0
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  CORR_LEN=$(jq '.correlations | length' "$DIR/profile.json" 2>/dev/null)
  check "corr float: pair count" "1" "$CORR_LEN"

  CORR_VAL=$(jq '.correlations[0].correlation' "$DIR/profile.json" 2>/dev/null)
  check "corr float: r=1" "1" "$CORR_VAL"
else
  skip "corr float: pair count"
  skip "corr float: r=1"
fi

# =============================================================================
# 138. Normalize + derive chain
# =============================================================================
echo ""
echo "=== 138. Normalize + derive chain ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_norm_derive
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,0
2,10
3,20
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[
  {"op": "normalize", "column": "value", "method": "minmax", "as": "norm"},
  {"op": "derive", "name": "double_norm", "expression": "norm * 2"}
]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv" 2>/dev/null)
  check_contains "norm derive chain: has norm" "norm" "$HEADER"
  check_contains "norm derive chain: has double_norm" "double_norm" "$HEADER"

  ROW2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  DNORM2=$(echo "$ROW2" | rev | cut -d',' -f1 | rev)
  check "norm derive chain: row2 double_norm=1" "1" "$DNORM2"
else
  skip "norm derive chain: has norm"
  skip "norm derive chain: has double_norm"
  skip "norm derive chain: row2 double_norm=1"
fi

# =============================================================================
# 139. Fill linear + assert chain
# =============================================================================
echo ""
echo "=== 139. Fill linear + assert chain ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_fill_assert
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,
3,30
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[
  {"op": "fill", "columns": ["value"], "strategy": "linear"},
  {"op": "assert", "expression": "value >= 10", "message": "value too low"}
]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null
  EXIT_CODE=$?
  check "fill assert chain: exit 0" "0" "$EXIT_CODE"

  ROW2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  V2=$(echo "$ROW2" | cut -d',' -f2)
  check "fill assert chain: row2=20" "20" "$V2"
else
  skip "fill assert chain: exit 0"
  skip "fill assert chain: row2=20"
fi

# =============================================================================
# 140. Fill linear + normalize chain
# =============================================================================
echo ""
echo "=== 140. Fill linear + normalize chain ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_fill_norm
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,0
2,
3,100
4,50
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[
  {"op": "fill", "columns": ["value"], "strategy": "linear"},
  {"op": "normalize", "column": "value", "method": "minmax", "as": "norm"}
]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv" 2>/dev/null)
  check_contains "fill norm chain: has norm" "norm" "$HEADER"

  ROW1=$(tail -n +2 "$DIR/out.csv" | head -1)
  N1=$(echo "$ROW1" | cut -d',' -f3)
  check "fill norm chain: row1 norm=0" "0" "$N1"

  ROW2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  N2=$(echo "$ROW2" | cut -d',' -f3)
  check "fill norm chain: row2 norm=0.5" "0.5" "$N2"

  ROW3=$(tail -n +2 "$DIR/out.csv" | sed -n '3p')
  N3=$(echo "$ROW3" | cut -d',' -f3)
  check "fill norm chain: row3 norm=1" "1" "$N3"

  ROW4=$(tail -n +2 "$DIR/out.csv" | sed -n '4p')
  N4=$(echo "$ROW4" | cut -d',' -f3)
  check "fill norm chain: row4 norm=0.5" "0.5" "$N4"
else
  skip "fill norm chain: has norm"
  skip "fill norm chain: row1 norm=0"
  skip "fill norm chain: row2 norm=0.5"
  skip "fill norm chain: row3 norm=1"
  skip "fill norm chain: row4 norm=0.5"
fi

# =============================================================================
# 141. Profile with one numeric column (empty correlations)
# =============================================================================
echo ""
echo "=== 141. Profile one numeric column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_corr_one
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,name
1,Alice
2,Bob
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  CORR_LEN=$(jq '.correlations | length' "$DIR/profile.json" 2>/dev/null)
  check "corr one col: empty array" "0" "$CORR_LEN"
else
  skip "corr one col: empty array"
fi

# =============================================================================
# 142. Profile correlations with partial missing values
# =============================================================================
echo ""
echo "=== 142. Profile corr partial missing ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_corr_partial
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
a,b
1,10
2,
3,30
,40
5,50
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  # Paired: (1,10), (3,30), (5,50) -> perfectly correlated
  CORR_VAL=$(jq '.correlations[0].correlation' "$DIR/profile.json" 2>/dev/null)
  check "corr partial: r=1" "1" "$CORR_VAL"
else
  skip "corr partial: r=1"
fi

# =============================================================================
# 143. Hash basic - single column
# =============================================================================
echo ""
echo "=== 143. Hash basic - single column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_hash_basic
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,name
1,Alice
2,Bob
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "hash", "columns": ["id"], "as": "id_hash"}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv")
  check "hash basic: header" "id,name,id_hash" "$HEADER"
  # SHA-256 of "1" = 6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b
  HASH1=$(awk -F, 'NR==2{print $3}' "$DIR/out.csv")
  check "hash basic: row1" "6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b" "$HASH1"
else
  skip "hash basic: header"
  skip "hash basic: row1"
fi

# =============================================================================
# 144. Hash multi-column with null separator
# =============================================================================
echo ""
echo "=== 144. Hash multi-column with null separator ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_hash_multi
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,name
1,Alice
2,Bob
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "hash", "columns": ["id", "name"], "as": "row_hash"}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  # SHA-256 of "1\x00Alice"
  EXPECTED=$(printf '1\x00Alice' | sha256sum | awk '{print $1}')
  ACTUAL=$(awk -F, 'NR==2{print $3}' "$DIR/out.csv")
  check "hash multi: row1" "$EXPECTED" "$ACTUAL"
else
  skip "hash multi: row1"
fi

# =============================================================================
# 145. Hash all columns (omit columns field)
# =============================================================================
echo ""
echo "=== 145. Hash all columns ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_hash_all
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
a,b,c
x,y,z
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "hash", "as": "h"}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  # SHA-256 of "x\x00y\x00z"
  EXPECTED=$(printf 'x\x00y\x00z' | sha256sum | awk '{print $1}')
  ACTUAL=$(awk -F, 'NR==2{print $4}' "$DIR/out.csv")
  check "hash all cols: row1" "$EXPECTED" "$ACTUAL"
else
  skip "hash all cols: row1"
fi

# =============================================================================
# 146. Hash with empty cell
# =============================================================================
echo ""
echo "=== 146. Hash with empty cell ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_hash_empty
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
a,b
x,
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "hash", "columns": ["a", "b"], "as": "h"}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  # SHA-256 of "x\x00" (x + null + empty)
  EXPECTED=$(printf 'x\x00' | sha256sum | awk '{print $1}')
  ACTUAL=$(awk -F, 'NR==2{print $3}' "$DIR/out.csv")
  check "hash empty cell: row1" "$EXPECTED" "$ACTUAL"
else
  skip "hash empty cell: row1"
fi

# =============================================================================
# 147. Hash column not found error
# =============================================================================
echo ""
echo "=== 147. Hash column not found ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_hash_err
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
a,b
1,2
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "hash", "columns": ["missing"], "as": "h"}]
EOF

  ERR=$($DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>&1 || true)
  check "hash col err" "ERROR: invalid recipe: column missing not found" "$ERR"
else
  skip "hash col err"
fi

# =============================================================================
# 148. Compare basic - added/removed/modified/unchanged
# =============================================================================
echo ""
echo "=== 148. Compare basic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_compare_basic
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name,value
1,Alice,10
2,Bob,20
3,Charlie,30
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,name,value
1,Alice,10
2,Bob,25
4,Diana,40
EOF

  $DPIPE compare --left "$DIR/left.csv" --right "$DIR/right.csv" --key id --output "$DIR/diff.json" 2>/dev/null

  LEFT_R=$(jq '.summary.left_rows' "$DIR/diff.json")
  RIGHT_R=$(jq '.summary.right_rows' "$DIR/diff.json")
  ADDED=$(jq '.summary.added' "$DIR/diff.json")
  REMOVED=$(jq '.summary.removed' "$DIR/diff.json")
  MODIFIED=$(jq '.summary.modified' "$DIR/diff.json")
  UNCHANGED=$(jq '.summary.unchanged' "$DIR/diff.json")

  check "cmp basic: left_rows" "3" "$LEFT_R"
  check "cmp basic: right_rows" "3" "$RIGHT_R"
  check "cmp basic: added" "1" "$ADDED"
  check "cmp basic: removed" "1" "$REMOVED"
  check "cmp basic: modified" "1" "$MODIFIED"
  check "cmp basic: unchanged" "1" "$UNCHANGED"
else
  skip "cmp basic: left_rows"
  skip "cmp basic: right_rows"
  skip "cmp basic: added"
  skip "cmp basic: removed"
  skip "cmp basic: modified"
  skip "cmp basic: unchanged"
fi

# =============================================================================
# 149. Compare changes ordering and content
# =============================================================================
echo ""
echo "=== 149. Compare changes ordering ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_compare_order
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name,value
1,Alice,10
2,Bob,20
3,Charlie,30
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,name,value
1,Alice,10
2,Bob,25
4,Diana,40
EOF

  $DPIPE compare --left "$DIR/left.csv" --right "$DIR/right.csv" --key id --output "$DIR/diff.json" 2>/dev/null

  # First change should be "added" (type order: added, removed, modified)
  TYPE0=$(jq -r '.changes[0].type' "$DIR/diff.json")
  check "cmp order: first=added" "added" "$TYPE0"
  KEY0=$(jq -r '.changes[0].key.id' "$DIR/diff.json")
  check "cmp order: added key" "4" "$KEY0"

  TYPE1=$(jq -r '.changes[1].type' "$DIR/diff.json")
  check "cmp order: second=removed" "removed" "$TYPE1"
  KEY1=$(jq -r '.changes[1].key.id' "$DIR/diff.json")
  check "cmp order: removed key" "3" "$KEY1"

  TYPE2=$(jq -r '.changes[2].type' "$DIR/diff.json")
  check "cmp order: third=modified" "modified" "$TYPE2"
  DIFF_COLS=$(jq -r '.changes[2].diff[0]' "$DIR/diff.json")
  check "cmp order: diff col" "value" "$DIFF_COLS"
else
  skip "cmp order: first=added"
  skip "cmp order: added key"
  skip "cmp order: second=removed"
  skip "cmp order: removed key"
  skip "cmp order: third=modified"
  skip "cmp order: diff col"
fi

# =============================================================================
# 150. Compare composite key
# =============================================================================
echo ""
echo "=== 150. Compare composite key ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_compare_compkey
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
dept,id,name
A,1,Alice
A,2,Bob
B,1,Charlie
EOF

  cat > "$DIR/right.csv" << 'EOF'
dept,id,name
A,1,Alice
A,2,Robert
B,2,Diana
EOF

  $DPIPE compare --left "$DIR/left.csv" --right "$DIR/right.csv" --key dept,id --output "$DIR/diff.json" 2>/dev/null

  ADDED=$(jq '.summary.added' "$DIR/diff.json")
  REMOVED=$(jq '.summary.removed' "$DIR/diff.json")
  MODIFIED=$(jq '.summary.modified' "$DIR/diff.json")
  UNCHANGED=$(jq '.summary.unchanged' "$DIR/diff.json")
  check "cmp compkey: added" "1" "$ADDED"
  check "cmp compkey: removed" "1" "$REMOVED"
  check "cmp compkey: modified" "1" "$MODIFIED"
  check "cmp compkey: unchanged" "1" "$UNCHANGED"
else
  skip "cmp compkey: added"
  skip "cmp compkey: removed"
  skip "cmp compkey: modified"
  skip "cmp compkey: unchanged"
fi

# =============================================================================
# 151. Compare schema mismatch error
# =============================================================================
echo ""
echo "=== 151. Compare schema mismatch ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_compare_schema
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name
1,Alice
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,value
1,10
EOF

  ERR=$($DPIPE compare --left "$DIR/left.csv" --right "$DIR/right.csv" --key id --output "$DIR/diff.json" 2>&1 || true)
  check "cmp schema err" "ERROR: schema mismatch: headers differ" "$ERR"
else
  skip "cmp schema err"
fi

# =============================================================================
# 152. Compare missing key flag error
# =============================================================================
echo ""
echo "=== 152. Compare missing key ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_compare_nokey
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name
1,Alice
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,name
1,Alice
EOF

  ERR=$($DPIPE compare --left "$DIR/left.csv" --right "$DIR/right.csv" --output "$DIR/diff.json" 2>&1 || true)
  check "cmp no key err" "ERROR: --key is required" "$ERR"
else
  skip "cmp no key err"
fi

# =============================================================================
# 153. Compare invalid key column error
# =============================================================================
echo ""
echo "=== 153. Compare invalid key column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_compare_badkey
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name
1,Alice
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,name
1,Alice
EOF

  ERR=$($DPIPE compare --left "$DIR/left.csv" --right "$DIR/right.csv" --key missing --output "$DIR/diff.json" 2>&1 || true)
  check "cmp bad key err" "ERROR: invalid key: column missing not found" "$ERR"
else
  skip "cmp bad key err"
fi

# =============================================================================
# 154. Compare file not found error
# =============================================================================
echo ""
echo "=== 154. Compare file not found ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_compare_nf
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name
1,Alice
EOF

  ERR=$($DPIPE compare --left "$DIR/left.csv" --right "$DIR/nonexistent.csv" --key id --output "$DIR/diff.json" 2>&1 || true)
  echo "$ERR" | grep -q "ERROR: file not found"
  if [ $? -eq 0 ]; then
    check "cmp file not found" "1" "1"
  else
    check "cmp file not found" "ERROR: file not found" "$ERR"
  fi
else
  skip "cmp file not found"
fi

# =============================================================================
# 155. Compare identical files
# =============================================================================
echo ""
echo "=== 155. Compare identical files ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_compare_ident
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,name,value
1,Alice,10
2,Bob,20
EOF

  $DPIPE compare --left "$DIR/data.csv" --right "$DIR/data.csv" --key id --output "$DIR/diff.json" 2>/dev/null

  ADDED=$(jq '.summary.added' "$DIR/diff.json")
  REMOVED=$(jq '.summary.removed' "$DIR/diff.json")
  MODIFIED=$(jq '.summary.modified' "$DIR/diff.json")
  UNCHANGED=$(jq '.summary.unchanged' "$DIR/diff.json")
  CHANGES_LEN=$(jq '.changes | length' "$DIR/diff.json")
  check "cmp ident: added" "0" "$ADDED"
  check "cmp ident: removed" "0" "$REMOVED"
  check "cmp ident: modified" "0" "$MODIFIED"
  check "cmp ident: unchanged" "2" "$UNCHANGED"
  check "cmp ident: changes empty" "0" "$CHANGES_LEN"
else
  skip "cmp ident: added"
  skip "cmp ident: removed"
  skip "cmp ident: modified"
  skip "cmp ident: unchanged"
  skip "cmp ident: changes empty"
fi

# =============================================================================
# 156. Compare duplicate keys - first occurrence used
# =============================================================================
echo ""
echo "=== 156. Compare duplicate keys ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_compare_dup
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name
1,Alice
1,Bob
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,name
1,Charlie
EOF

  $DPIPE compare --left "$DIR/left.csv" --right "$DIR/right.csv" --key id --output "$DIR/diff.json" 2>/dev/null

  # Left uses first occurrence (Alice), right has Charlie -> modified
  MODIFIED=$(jq '.summary.modified' "$DIR/diff.json")
  check "cmp dup: modified" "1" "$MODIFIED"
  LEFT_NAME=$(jq -r '.changes[0].left.name' "$DIR/diff.json")
  check "cmp dup: left name" "Alice" "$LEFT_NAME"
else
  skip "cmp dup: modified"
  skip "cmp dup: left name"
fi

# =============================================================================
# 157. Compare modified row diff field
# =============================================================================
echo ""
echo "=== 157. Compare modified diff field ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_compare_diff
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name,score,grade
1,Alice,90,A
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,name,score,grade
1,Alice,85,B
EOF

  $DPIPE compare --left "$DIR/left.csv" --right "$DIR/right.csv" --key id --output "$DIR/diff.json" 2>/dev/null

  DIFF0=$(jq -r '.changes[0].diff[0]' "$DIR/diff.json")
  DIFF1=$(jq -r '.changes[0].diff[1]' "$DIR/diff.json")
  check "cmp diff: col0" "score" "$DIFF0"
  check "cmp diff: col1" "grade" "$DIFF1"
else
  skip "cmp diff: col0"
  skip "cmp diff: col1"
fi

# =============================================================================
# 158. Compare pipeline step
# =============================================================================
echo ""
echo "=== 158. Compare pipeline step ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_compare_pipe
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,value
1,10
2,20
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,value
1,10
3,30
EOF

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 0,
  "steps": [
    {"type": "compare", "left": "left.csv", "right": "right.csv", "key": "id", "output": "diff.json"}
  ]
}
EOF

  (cd "$DIR" && $DPIPE pipeline --config pipeline.json 2>/dev/null)

  ADDED=$(jq '.summary.added' "$DIR/diff.json")
  REMOVED=$(jq '.summary.removed' "$DIR/diff.json")
  check "cmp pipe: added" "1" "$ADDED"
  check "cmp pipe: removed" "1" "$REMOVED"
else
  skip "cmp pipe: added"
  skip "cmp pipe: removed"
fi

# =============================================================================
# 159. Hash deterministic - same input same output
# =============================================================================
echo ""
echo "=== 159. Hash deterministic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_hash_det
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
x,y
hello,world
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "hash", "columns": ["x", "y"], "as": "h"}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out1.csv" --seed 0 2>/dev/null
  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out2.csv" --seed 42 2>/dev/null

  H1=$(awk -F, 'NR==2{print $3}' "$DIR/out1.csv")
  H2=$(awk -F, 'NR==2{print $3}' "$DIR/out2.csv")
  check "hash deterministic" "$H1" "$H2"
else
  skip "hash deterministic"
fi

# =============================================================================
# 160. Compare missing output flag
# =============================================================================
echo ""
echo "=== 160. Compare missing output ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_compare_noout
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name
1,Alice
EOF
  cat > "$DIR/right.csv" << 'EOF'
id,name
1,Alice
EOF

  ERR=$($DPIPE compare --left "$DIR/left.csv" --right "$DIR/right.csv" --key id 2>&1 || true)
  check "cmp no output err" "ERROR: --output is required" "$ERR"
else
  skip "cmp no output err"
fi

# =============================================================================
# 161. Hash + Compare end-to-end reproducibility check
# =============================================================================
echo ""
echo "=== 161. Hash + Compare e2e ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_hash_compare_e2e
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,name,value
1,Alice,10
2,Bob,20
3,Charlie,30
EOF

  # Hash original data
  cat > "$DIR/recipe_hash.json" << 'EOF'
[{"op": "hash", "columns": ["name", "value"], "as": "checksum"}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe_hash.json" --output "$DIR/hashed.csv" --seed 0 2>/dev/null

  # Modify one row and re-hash
  cat > "$DIR/data2.csv" << 'EOF'
id,name,value
1,Alice,10
2,Bob,25
3,Charlie,30
EOF

  $DPIPE transform --input "$DIR/data2.csv" --recipe "$DIR/recipe_hash.json" --output "$DIR/hashed2.csv" --seed 0 2>/dev/null

  # Compare the hashed versions
  $DPIPE compare --left "$DIR/hashed.csv" --right "$DIR/hashed2.csv" --key id --output "$DIR/diff.json" 2>/dev/null

  MODIFIED=$(jq '.summary.modified' "$DIR/diff.json")
  check "hash+cmp e2e: modified" "1" "$MODIFIED"
  # The diff should include both value and checksum
  DIFF_LEN=$(jq '.changes[0].diff | length' "$DIR/diff.json")
  check "hash+cmp e2e: diff cols" "2" "$DIFF_LEN"
else
  skip "hash+cmp e2e: modified"
  skip "hash+cmp e2e: diff cols"
fi

# =============================================================================
# 162. Compare added row content
# =============================================================================
echo ""
echo "=== 162. Compare added row content ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_compare_added_content
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name
1,Alice
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,name
1,Alice
2,Bob
EOF

  $DPIPE compare --left "$DIR/left.csv" --right "$DIR/right.csv" --key id --output "$DIR/diff.json" 2>/dev/null

  ROW_NAME=$(jq -r '.changes[0].row.name' "$DIR/diff.json")
  check "cmp added content: name" "Bob" "$ROW_NAME"
  ROW_ID=$(jq -r '.changes[0].row.id' "$DIR/diff.json")
  check "cmp added content: id" "2" "$ROW_ID"
else
  skip "cmp added content: name"
  skip "cmp added content: id"
fi

# =============================================================================
# 163. Profile skewness (right-skewed data)
# =============================================================================
echo ""
echo "=== 163. Profile skewness (right-skewed) ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_skewness1
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,val
1,1
2,2
3,3
4,4
5,10
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  SKEW=$(jq '.columns[1].skewness' "$DIR/profile.json")
  EXPECTED=$(python3 -c "
import math
vals=[1,2,3,4,10]; n=len(vals); m=sum(vals)/n
s=math.sqrt(sum((x-m)**2 for x in vals)/(n-1))
sk=(n/((n-1)*(n-2)))*sum(((x-m)/s)**3 for x in vals)
print(f'{sk:.15g}')
")
  check_approx "profile skewness right-skewed" "$EXPECTED" "$SKEW"
else
  skip "profile skewness right-skewed"
fi

# =============================================================================
# 164. Profile skewness (symmetric data)
# =============================================================================
echo ""
echo "=== 164. Profile skewness (symmetric) ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_skewness2
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,val
1,1
2,2
3,3
4,4
5,5
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  SKEW=$(jq '.columns[1].skewness' "$DIR/profile.json")
  check "profile skewness symmetric" "0" "$SKEW"
else
  skip "profile skewness symmetric"
fi

# =============================================================================
# 165. Profile skewness null (n<3)
# =============================================================================
echo ""
echo "=== 165. Profile skewness null (n<3) ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_skewness3
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,val
1,10
2,20
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  SKEW=$(jq '.columns[1].skewness' "$DIR/profile.json")
  check "profile skewness null n<3" "null" "$SKEW"
else
  skip "profile skewness null n<3"
fi

# =============================================================================
# 166. Profile kurtosis (right-skewed data)
# =============================================================================
echo ""
echo "=== 166. Profile kurtosis ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_kurtosis1
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,val
1,1
2,2
3,3
4,4
5,10
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  KURT=$(jq '.columns[1].kurtosis' "$DIR/profile.json")
  EXPECTED=$(python3 -c "
import math
vals=[1,2,3,4,10]; n=len(vals); m=sum(vals)/n
s=math.sqrt(sum((x-m)**2 for x in vals)/(n-1))
sum4=sum(((x-m)/s)**4 for x in vals)
kurt=((n*(n+1))/((n-1)*(n-2)*(n-3)))*sum4 - (3*(n-1)**2)/((n-2)*(n-3))
print(f'{kurt:.15g}')
")
  check_approx "profile kurtosis" "$EXPECTED" "$KURT"
else
  skip "profile kurtosis"
fi

# =============================================================================
# 167. Profile kurtosis (symmetric uniform data)
# =============================================================================
echo ""
echo "=== 167. Profile kurtosis symmetric ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_kurtosis2
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,val
1,1
2,2
3,3
4,4
5,5
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  KURT=$(jq '.columns[1].kurtosis' "$DIR/profile.json")
  EXPECTED=$(python3 -c "
import math
vals=[1,2,3,4,5]; n=len(vals); m=sum(vals)/n
s=math.sqrt(sum((x-m)**2 for x in vals)/(n-1))
sum4=sum(((x-m)/s)**4 for x in vals)
kurt=((n*(n+1))/((n-1)*(n-2)*(n-3)))*sum4 - (3*(n-1)**2)/((n-2)*(n-3))
print(f'{kurt:.15g}')
")
  check_approx "profile kurtosis symmetric" "$EXPECTED" "$KURT"
else
  skip "profile kurtosis symmetric"
fi

# =============================================================================
# 168. Profile kurtosis null (n<4)
# =============================================================================
echo ""
echo "=== 168. Profile kurtosis null (n<4) ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_kurtosis3
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,val
1,10
2,20
3,30
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  KURT=$(jq '.columns[1].kurtosis' "$DIR/profile.json")
  check "profile kurtosis null n<4" "null" "$KURT"
else
  skip "profile kurtosis null n<4"
fi

# =============================================================================
# 169. Profile mode (basic)
# =============================================================================
echo ""
echo "=== 169. Profile mode basic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_mode1
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,val
1,1
2,2
3,2
4,3
5,3
6,3
7,4
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  MODE=$(jq '.columns[1].mode' "$DIR/profile.json")
  check "profile mode basic" "3" "$MODE"
else
  skip "profile mode basic"
fi

# =============================================================================
# 170. Profile mode (tie - smallest wins)
# =============================================================================
echo ""
echo "=== 170. Profile mode tie ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_mode2
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,val
1,1
2,1
3,2
4,2
5,3
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  MODE=$(jq '.columns[1].mode' "$DIR/profile.json")
  check "profile mode tie smallest" "1" "$MODE"
else
  skip "profile mode tie smallest"
fi

# =============================================================================
# 171. Profile mode null (all unique)
# =============================================================================
echo ""
echo "=== 171. Profile mode null ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_mode3
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,val
1,10
2,20
3,30
4,40
5,50
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  MODE=$(jq '.columns[1].mode' "$DIR/profile.json")
  check "profile mode null unique" "null" "$MODE"
else
  skip "profile mode null unique"
fi

# =============================================================================
# 172. Profile histogram (basic 5 values)
# =============================================================================
echo ""
echo "=== 172. Profile histogram basic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_hist1
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,val
1,10
2,20
3,30
4,40
5,50
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  HIST_LEN=$(jq '.columns[1].histogram | length' "$DIR/profile.json")
  check "profile histogram length" "10" "$HIST_LEN"
  # val 10 -> bin 0 (floor((10-10)/4)=0), val 20 -> bin 2 (floor(10/4)=2), val 30 -> bin 5 (floor(20/4)=5), val 40 -> bin 7 (floor(30/4)=7), val 50 -> bin 9 (clamped)
  BIN0_COUNT=$(jq '.columns[1].histogram[0].count' "$DIR/profile.json")
  check "profile histogram bin0" "1" "$BIN0_COUNT"
  BIN9_COUNT=$(jq '.columns[1].histogram[9].count' "$DIR/profile.json")
  check "profile histogram bin9" "1" "$BIN9_COUNT"
  BIN0_LOW=$(jq '.columns[1].histogram[0].low' "$DIR/profile.json")
  check "profile histogram bin0 low" "10" "$BIN0_LOW"
else
  skip "profile histogram length"
  skip "profile histogram bin0"
  skip "profile histogram bin9"
  skip "profile histogram bin0 low"
fi

# =============================================================================
# 173. Profile histogram (all identical)
# =============================================================================
echo ""
echo "=== 173. Profile histogram identical ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_hist2
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,val
1,5
2,5
3,5
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  HIST_LEN=$(jq '.columns[1].histogram | length' "$DIR/profile.json")
  check "profile histogram identical length" "1" "$HIST_LEN"
  HIST_COUNT=$(jq '.columns[1].histogram[0].count' "$DIR/profile.json")
  check "profile histogram identical count" "3" "$HIST_COUNT"
  HIST_LOW=$(jq '.columns[1].histogram[0].low' "$DIR/profile.json")
  check "profile histogram identical low" "5" "$HIST_LOW"
else
  skip "profile histogram identical length"
  skip "profile histogram identical count"
  skip "profile histogram identical low"
fi

# =============================================================================
# 174. Profile avg_length for strings
# =============================================================================
echo ""
echo "=== 174. Profile avg_length ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_avglength
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,name
1,hello
2,hi
3,hey
4,howdy
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  AVG_LEN=$(jq '.columns[1].avg_length' "$DIR/profile.json")
  check "profile avg_length" "3.75" "$AVG_LEN"
else
  skip "profile avg_length"
fi

# =============================================================================
# 175. Encode onehot (drop=true)
# =============================================================================
echo ""
echo "=== 175. Encode onehot drop ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_encode_oh_drop
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,color,value
1,red,10
2,blue,20
3,green,30
4,red,40
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "encode", "column": "color", "method": "onehot", "drop": true}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv")
  check "encode onehot drop header" "id,color_blue,color_green,color_red,value" "$HEADER"
  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "encode onehot drop row1" "1,0,0,1,10" "$ROW1"
  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "encode onehot drop row2" "2,1,0,0,20" "$ROW2"
else
  skip "encode onehot drop header"
  skip "encode onehot drop row1"
  skip "encode onehot drop row2"
fi

# =============================================================================
# 176. Encode onehot (drop=false, default)
# =============================================================================
echo ""
echo "=== 176. Encode onehot no-drop ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_encode_oh_nodrop
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,color,value
1,red,10
2,blue,20
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "encode", "column": "color", "method": "onehot"}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv")
  check "encode onehot nodrop header" "id,color,value,color_blue,color_red" "$HEADER"
  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "encode onehot nodrop row1" "1,red,10,0,1" "$ROW1"
else
  skip "encode onehot nodrop header"
  skip "encode onehot nodrop row1"
fi

# =============================================================================
# 177. Encode ordinal
# =============================================================================
echo ""
echo "=== 177. Encode ordinal ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_encode_ord
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,status
1,high
2,low
3,medium
4,high
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "encode", "column": "status", "method": "ordinal", "as": "status_code"}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv")
  check "encode ordinal header" "id,status,status_code" "$HEADER"
  # sorted: high=0, low=1, medium=2
  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "encode ordinal row1 high" "1,high,0" "$ROW1"
  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "encode ordinal row2 low" "2,low,1" "$ROW2"
  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "encode ordinal row3 medium" "3,medium,2" "$ROW3"
else
  skip "encode ordinal header"
  skip "encode ordinal row1 high"
  skip "encode ordinal row2 low"
  skip "encode ordinal row3 medium"
fi

# =============================================================================
# 178. Rollup single grouping column
# =============================================================================
echo ""
echo "=== 178. Rollup single column ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_rollup1
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
region,sales
East,100
East,200
West,300
West,400
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "rollup", "columns": ["region"], "aggregations": [{"column": "sales", "function": "sum", "as": "total"}]}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv")
  check "rollup single header" "region,total" "$HEADER"
  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "rollup single row1 East" "East,300" "$ROW1"
  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "rollup single row2 West" "West,700" "$ROW2"
  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "rollup single grand total" "*,1000" "$ROW3"
else
  skip "rollup single header"
  skip "rollup single row1 East"
  skip "rollup single row2 West"
  skip "rollup single grand total"
fi

# =============================================================================
# 179. Rollup two grouping columns
# =============================================================================
echo ""
echo "=== 179. Rollup two columns ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_rollup2
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
region,city,sales
East,NYC,100
East,BOS,200
West,LA,300
West,SF,400
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "rollup", "columns": ["region", "city"], "aggregations": [{"column": "sales", "function": "sum", "as": "total"}]}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv")
  check "rollup two header" "region,city,total" "$HEADER"
  # Detail rows sorted: East+BOS, East+NYC, West+LA, West+SF
  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "rollup two detail1" "East,BOS,200" "$ROW1"
  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "rollup two detail2" "East,NYC,100" "$ROW2"
  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "rollup two detail3" "West,LA,300" "$ROW3"
  ROW4=$(sed -n '5p' "$DIR/out.csv")
  check "rollup two detail4" "West,SF,400" "$ROW4"
  # Subtotals for region (level 1)
  ROW5=$(sed -n '6p' "$DIR/out.csv")
  check "rollup two subtotal East" "East,*,300" "$ROW5"
  ROW6=$(sed -n '7p' "$DIR/out.csv")
  check "rollup two subtotal West" "West,*,700" "$ROW6"
  # Grand total
  ROW7=$(sed -n '8p' "$DIR/out.csv")
  check "rollup two grand total" "*,*,1000" "$ROW7"
else
  skip "rollup two header"
  skip "rollup two detail1"
  skip "rollup two detail2"
  skip "rollup two detail3"
  skip "rollup two detail4"
  skip "rollup two subtotal East"
  skip "rollup two subtotal West"
  skip "rollup two grand total"
fi

# =============================================================================
# 180. Detect IQR outliers
# =============================================================================
echo ""
echo "=== 180. Detect IQR ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_detect_iqr
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,1
2,2
3,3
4,4
5,100
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "detect", "column": "value", "method": "iqr", "as": "is_outlier", "factor": 1.5}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  # Q1=2, Q3=4, IQR=2, bounds=[-1,7]. 100 > 7 = outlier
  ROW1_OUT=$(sed -n '2p' "$DIR/out.csv" | cut -d',' -f3)
  check "detect iqr normal val=1" "0" "$ROW1_OUT"
  ROW5_OUT=$(sed -n '6p' "$DIR/out.csv" | cut -d',' -f3)
  check "detect iqr outlier val=100" "1" "$ROW5_OUT"
else
  skip "detect iqr normal val=1"
  skip "detect iqr outlier val=100"
fi

# =============================================================================
# 181. Detect zscore outliers
# =============================================================================
echo ""
echo "=== 181. Detect zscore ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_detect_zs
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,10
2,10
3,10
4,10
5,100
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "detect", "column": "value", "method": "zscore", "as": "is_outlier", "factor": 1.5}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  ROW1_OUT=$(sed -n '2p' "$DIR/out.csv" | cut -d',' -f3)
  check "detect zscore normal val=10" "0" "$ROW1_OUT"
  ROW5_OUT=$(sed -n '6p' "$DIR/out.csv" | cut -d',' -f3)
  check "detect zscore outlier val=100" "1" "$ROW5_OUT"
else
  skip "detect zscore normal val=10"
  skip "detect zscore outlier val=100"
fi

# =============================================================================
# 182. Detect MAD outliers
# =============================================================================
echo ""
echo "=== 182. Detect MAD ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_detect_mad
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,1
2,2
3,3
4,4
5,100
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "detect", "column": "value", "method": "mad", "as": "is_outlier", "factor": 3.5}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  # median=3, deviations=[2,1,0,1,97], MAD=1, modified_z(100) = 0.6745*(100-3)/1 = 65.4265 > 3.5
  ROW1_OUT=$(sed -n '2p' "$DIR/out.csv" | cut -d',' -f3)
  check "detect mad normal val=1" "0" "$ROW1_OUT"
  ROW5_OUT=$(sed -n '6p' "$DIR/out.csv" | cut -d',' -f3)
  check "detect mad outlier val=100" "1" "$ROW5_OUT"
else
  skip "detect mad normal val=1"
  skip "detect mad outlier val=100"
fi

# =============================================================================
# 183. Detect MAD with MAD=0 edge case
# =============================================================================
echo ""
echo "=== 183. Detect MAD zero ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_detect_mad0
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,5
2,5
3,5
4,5
5,99
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "detect", "column": "value", "method": "mad", "as": "is_outlier", "factor": 3.5}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  # median=5, MAD=0 => values equal to median get "0", others get "1"
  ROW1_OUT=$(sed -n '2p' "$DIR/out.csv" | cut -d',' -f3)
  check "detect mad0 val=5 not outlier" "0" "$ROW1_OUT"
  ROW5_OUT=$(sed -n '6p' "$DIR/out.csv" | cut -d',' -f3)
  check "detect mad0 val=99 outlier" "1" "$ROW5_OUT"
else
  skip "detect mad0 val=5 not outlier"
  skip "detect mad0 val=99 outlier"
fi

# =============================================================================
# 184. Bin width method
# =============================================================================
echo ""
echo "=== 184. Bin width ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_bin_width
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,0
2,25
3,50
4,75
5,100
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "bin", "column": "value", "method": "width", "bins": 4, "as": "bucket"}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  # width=25, bins: [0,25), [25,50), [50,75), [75,100]
  ROW1_BIN=$(sed -n '2p' "$DIR/out.csv" | cut -d',' -f3- | tr -d '"')
  check "bin width val=0" "[0,25)" "$ROW1_BIN"
  ROW2_BIN=$(sed -n '3p' "$DIR/out.csv" | cut -d',' -f3- | tr -d '"')
  check "bin width val=25" "[25,50)" "$ROW2_BIN"
  ROW5_BIN=$(sed -n '6p' "$DIR/out.csv" | cut -d',' -f3- | tr -d '"')
  check "bin width val=100 last" "[75,100]" "$ROW5_BIN"
else
  skip "bin width val=0"
  skip "bin width val=25"
  skip "bin width val=100 last"
fi

# =============================================================================
# 185. Bin quantile method
# =============================================================================
echo ""
echo "=== 185. Bin quantile ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_bin_quantile
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,1
2,2
3,3
4,4
5,5
6,6
7,7
8,8
9,9
10,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "bin", "column": "value", "method": "quantile", "bins": 4, "as": "quartile"}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  # Boundaries: p0=1, p25=3.25, p50=5.5, p75=7.75, p100=10
  ROW1_BIN=$(sed -n '2p' "$DIR/out.csv" | cut -d',' -f3- | tr -d '"')
  check "bin quantile val=1" "[1,3.25)" "$ROW1_BIN"
  ROW10_BIN=$(sed -n '11p' "$DIR/out.csv" | cut -d',' -f3- | tr -d '"')
  check "bin quantile val=10 last" "[7.75,10]" "$ROW10_BIN"
else
  skip "bin quantile val=1"
  skip "bin quantile val=10 last"
fi

# =============================================================================
# 186. Bin all-same values
# =============================================================================
echo ""
echo "=== 186. Bin same values ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_bin_same
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,value
1,5
2,5
3,5
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "bin", "column": "value", "method": "width", "bins": 3, "as": "bucket"}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  ROW1_BIN=$(sed -n '2p' "$DIR/out.csv" | cut -d',' -f3- | tr -d '"')
  check "bin same values" "[5,5]" "$ROW1_BIN"
else
  skip "bin same values"
fi

# =============================================================================
# 187. Compare with --tolerance
# =============================================================================
echo ""
echo "=== 187. Compare tolerance ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_cmp_tol
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name,score
1,Alice,99.99
2,Bob,50.0
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,name,score
1,Alice,100.0
2,Bob,50.05
EOF

  $DPIPE compare --left "$DIR/left.csv" --right "$DIR/right.csv" --key id --tolerance 0.02 --output "$DIR/diff.json" 2>/dev/null

  # score diff for Alice: |99.99 - 100.0| = 0.01 <= 0.02 => equal
  # score diff for Bob: |50.0 - 50.05| = 0.05 > 0.02 => modified
  MODIFIED=$(jq '.summary.modified' "$DIR/diff.json")
  check "cmp tolerance modified" "1" "$MODIFIED"
  UNCHANGED=$(jq '.summary.unchanged' "$DIR/diff.json")
  check "cmp tolerance unchanged" "1" "$UNCHANGED"
  DIFF_KEY=$(jq -r '.changes[0].key.id' "$DIR/diff.json")
  check "cmp tolerance mod key" "2" "$DIFF_KEY"
else
  skip "cmp tolerance modified"
  skip "cmp tolerance unchanged"
  skip "cmp tolerance mod key"
fi

# =============================================================================
# 188. Compare with --ignore
# =============================================================================
echo ""
echo "=== 188. Compare ignore ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_cmp_ignore
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name,score,updated
1,Alice,90,2024-01-01
2,Bob,80,2024-01-01
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,name,score,updated
1,Alice,90,2024-06-15
2,Bob,85,2024-06-15
EOF

  $DPIPE compare --left "$DIR/left.csv" --right "$DIR/right.csv" --key id --ignore updated --output "$DIR/diff.json" 2>/dev/null

  # Ignoring updated: Alice unchanged, Bob score differs
  MODIFIED=$(jq '.summary.modified' "$DIR/diff.json")
  check "cmp ignore modified" "1" "$MODIFIED"
  UNCHANGED=$(jq '.summary.unchanged' "$DIR/diff.json")
  check "cmp ignore unchanged" "1" "$UNCHANGED"
  # diff array should NOT include "updated"
  HAS_UPDATED=$(jq -r '.changes[0].diff | index("updated") // "none"' "$DIR/diff.json")
  check "cmp ignore diff no updated" "none" "$HAS_UPDATED"
  HAS_SCORE=$(jq -r '.changes[0].diff[0]' "$DIR/diff.json")
  check "cmp ignore diff has score" "score" "$HAS_SCORE"
else
  skip "cmp ignore modified"
  skip "cmp ignore unchanged"
  skip "cmp ignore diff no updated"
  skip "cmp ignore diff has score"
fi

# =============================================================================
# 189. Compare --ignore invalid column
# =============================================================================
echo ""
echo "=== 189. Compare ignore invalid ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_cmp_ignore_invalid
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
id,name
1,Alice
EOF

  cat > "$DIR/right.csv" << 'EOF'
id,name
1,Alice
EOF

  ERR=$($DPIPE compare --left "$DIR/left.csv" --right "$DIR/right.csv" --key id --ignore nonexistent --output "$DIR/diff.json" 2>&1)
  EC=$?
  check "cmp ignore invalid exit" "1" "$EC"
  check_contains "cmp ignore invalid msg" "invalid ignore: column nonexistent not found" "$ERR"
else
  skip "cmp ignore invalid exit"
  skip "cmp ignore invalid msg"
fi

# =============================================================================
# 190. Profile histogram bin assignment verification
# =============================================================================
echo ""
echo "=== 190. Profile histogram bin counts ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_hist_verify
  mkdir -p "$DIR"

  # Create 10 values evenly spread
  cat > "$DIR/data.csv" << 'EOF'
id,val
1,0
2,10
3,20
4,30
5,40
6,50
7,60
8,70
9,80
10,100
EOF

  $DPIPE profile --input "$DIR/data.csv" --output "$DIR/profile.json" 2>/dev/null

  # width = (100-0)/10 = 10. val 0 -> bin 0, 10 -> bin 1, ..., 80 -> bin 8, 100 -> bin 9 (clamped)
  BIN0=$(jq '.columns[1].histogram[0].count' "$DIR/profile.json")
  check "hist verify bin0" "1" "$BIN0"
  BIN1=$(jq '.columns[1].histogram[1].count' "$DIR/profile.json")
  check "hist verify bin1" "1" "$BIN1"
  BIN9=$(jq '.columns[1].histogram[9].count' "$DIR/profile.json")
  # val 100: floor((100-0)/10) = 10, clamped to 9. So bin9 has values 90 and 100? No, only 100.
  check "hist verify bin9" "1" "$BIN9"
  # bin 5: val 50 -> floor(50/10)=5
  BIN5=$(jq '.columns[1].histogram[5].count' "$DIR/profile.json")
  check "hist verify bin5" "1" "$BIN5"
else
  skip "hist verify bin0"
  skip "hist verify bin1"
  skip "hist verify bin9"
  skip "hist verify bin5"
fi

# =============================================================================
# 191. Encode onehot with empty values
# =============================================================================
echo ""
echo "=== 191. Encode onehot empty ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_encode_empty
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,color
1,red
2,
3,blue
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "encode", "column": "color", "method": "onehot", "drop": true}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv")
  check "encode empty header" "id,color_blue,color_red" "$HEADER"
  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "encode empty row2 all zero" "2,0,0" "$ROW2"
else
  skip "encode empty header"
  skip "encode empty row2 all zero"
fi

# =============================================================================
# 192. Rollup with avg aggregation
# =============================================================================
echo ""
echo "=== 192. Rollup avg ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_rollup_avg
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
dept,salary
Sales,50000
Sales,60000
Eng,80000
Eng,90000
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "rollup", "columns": ["dept"], "aggregations": [{"column": "salary", "function": "avg", "as": "avg_sal"},{"column": "salary", "function": "count", "as": "cnt"}]}]
EOF

  $DPIPE transform --input "$DIR/data.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv")
  check "rollup avg header" "dept,avg_sal,cnt" "$HEADER"
  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "rollup avg Eng" "Eng,85000,2" "$ROW1"
  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "rollup avg Sales" "Sales,55000,2" "$ROW2"
  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "rollup avg grand" "*,70000,4" "$ROW3"
else
  skip "rollup avg header"
  skip "rollup avg Eng"
  skip "rollup avg Sales"
  skip "rollup avg grand"
fi



# =============================================================================
# 193. Fill linear boundary extrapolation (extended)
# =============================================================================
echo ""
echo "=== 193. Fill linear boundary extrapolation ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_fill_lin_extrap
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
x,y
1,
2,
3,100
4,
5,200
6,
7,
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "fill", "columns": ["y"], "strategy": "linear"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  Y1=$(tail -n +2 "$DIR/out.csv" | sed -n '1p' | cut -d',' -f2)
  check "fill extrap: row1 upper anchor" "100" "$Y1"

  Y2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p' | cut -d',' -f2)
  check "fill extrap: row2 upper anchor" "100" "$Y2"

  Y4=$(tail -n +2 "$DIR/out.csv" | sed -n '4p' | cut -d',' -f2)
  check "fill extrap: row4 interpolated" "150" "$Y4"

  Y6=$(tail -n +2 "$DIR/out.csv" | sed -n '6p' | cut -d',' -f2)
  check "fill extrap: row6 lower anchor" "200" "$Y6"

  Y7=$(tail -n +2 "$DIR/out.csv" | sed -n '7p' | cut -d',' -f2)
  check "fill extrap: row7 lower anchor" "200" "$Y7"
else
  skip "fill extrap: row1 upper anchor"
  skip "fill extrap: row2 upper anchor"
  skip "fill extrap: row4 interpolated"
  skip "fill extrap: row6 lower anchor"
  skip "fill extrap: row7 lower anchor"
fi

# =============================================================================
# 194. Profile p05 and p95
# =============================================================================
echo ""
echo "=== 194. Profile p05 and p95 ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_profile_p05p95
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id
1
2
3
4
5
6
7
8
9
10
EOF

  $DPIPE profile --input "$DIR/input.csv" --output "$DIR/profile.json" 2>/dev/null

  P05=$(python3 -c "import json; d=json.load(open('$DIR/profile.json')); print(d['columns'][0].get('p05','MISSING'))")
  check_approx "profile p05=1.45" "1.45" "$P05"

  P95=$(python3 -c "import json; d=json.load(open('$DIR/profile.json')); print(d['columns'][0].get('p95','MISSING'))")
  check_approx "profile p95=9.55" "9.55" "$P95"

  P25=$(python3 -c "import json; d=json.load(open('$DIR/profile.json')); print(d['columns'][0].get('p25','MISSING'))")
  check_approx "profile p25 still correct" "3.25" "$P25"

  P75=$(python3 -c "import json; d=json.load(open('$DIR/profile.json')); print(d['columns'][0].get('p75','MISSING'))")
  check_approx "profile p75 still correct" "7.75" "$P75"
else
  skip "profile p05=1.45"
  skip "profile p95=9.55"
  skip "profile p25 still correct"
  skip "profile p75 still correct"
fi

# =============================================================================
# 195. Drift: schema drift detection
# =============================================================================
echo ""
echo "=== 195. Drift schema ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_drift_schema
  mkdir -p "$DIR"

  cat > "$DIR/baseline.csv" << 'EOF'
age
1
2
3
4
5
EOF

  cat > "$DIR/current.csv" << 'EOF'
name
Alice
Bob
Charlie
Dave
Eve
EOF

  $DPIPE drift --baseline "$DIR/baseline.csv" --current "$DIR/current.csv" --output "$DIR/drift.json" 2>/dev/null
  RET=$?
  check "drift schema: exit code 0" "0" "$RET"

  TOTAL_D=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['summary']['total_drifts'])")
  check "drift schema: total_drifts=2" "2" "$TOTAL_D"

  SCHEMA_D=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['summary']['schema_drifts'])")
  check "drift schema: schema_drifts=2" "2" "$SCHEMA_D"

  D0_COL=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['drifts'][0]['column'])")
  check "drift schema: first drift col=age" "age" "$D0_COL"

  D0_TYPE=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['drifts'][0]['drift_type'])")
  check "drift schema: first drift type=column_removed" "column_removed" "$D0_TYPE"

  D1_COL=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['drifts'][1]['column'])")
  check "drift schema: second drift col=name" "name" "$D1_COL"

  D1_TYPE=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['drifts'][1]['drift_type'])")
  check "drift schema: second drift type=column_added" "column_added" "$D1_TYPE"
else
  skip "drift schema: exit code 0"
  skip "drift schema: total_drifts=2"
  skip "drift schema: schema_drifts=2"
  skip "drift schema: first drift col=age"
  skip "drift schema: first drift type=column_removed"
  skip "drift schema: second drift col=name"
  skip "drift schema: second drift type=column_added"
fi

# =============================================================================
# 196. Drift: distribution drift detection
# =============================================================================
echo ""
echo "=== 196. Drift distribution ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_drift_dist
  mkdir -p "$DIR"

  cat > "$DIR/baseline.csv" << 'EOF'
score
0.0
100.0
EOF

  cat > "$DIR/current.csv" << 'EOF'
score
0.0
200.0
EOF

  $DPIPE drift --baseline "$DIR/baseline.csv" --current "$DIR/current.csv" --output "$DIR/drift.json" 2>/dev/null

  TOTAL_D=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['summary']['total_drifts'])")
  check "drift dist: total_drifts=2" "2" "$TOTAL_D"

  DIST_D=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['summary']['distribution_drifts'])")
  check "drift dist: distribution_drifts=2" "2" "$DIST_D"

  D0_TYPE=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['drifts'][0]['drift_type'])")
  check "drift dist: first=mean_shift" "mean_shift" "$D0_TYPE"

  D1_TYPE=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['drifts'][1]['drift_type'])")
  check "drift dist: second=range_expansion" "range_expansion" "$D1_TYPE"

  DETAIL=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['drifts'][0]['detail'])")
  check "drift dist: mean shift detail" "normalized shift = 1" "$DETAIL"
else
  skip "drift dist: total_drifts=2"
  skip "drift dist: distribution_drifts=2"
  skip "drift dist: first=mean_shift"
  skip "drift dist: second=range_expansion"
  skip "drift dist: mean shift detail"
fi

# =============================================================================
# 197. Drift: no drift case
# =============================================================================
echo ""
echo "=== 197. Drift no drift ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_drift_nodrift
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
val
1
2
3
4
5
EOF

  $DPIPE drift --baseline "$DIR/data.csv" --current "$DIR/data.csv" --output "$DIR/drift.json" 2>/dev/null

  TOTAL_D=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['summary']['total_drifts'])")
  check "drift nodrift: total_drifts=0" "0" "$TOTAL_D"

  DRIFTS_LEN=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(len(d['drifts']))")
  check "drift nodrift: drifts empty" "0" "$DRIFTS_LEN"
else
  skip "drift nodrift: total_drifts=0"
  skip "drift nodrift: drifts empty"
fi

# =============================================================================
# 198. Drift: missing file error
# =============================================================================
echo ""
echo "=== 198. Drift error ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_drift_err
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
x
1
EOF

  $DPIPE drift --baseline "$DIR/nonexist.csv" --current "$DIR/data.csv" --output "$DIR/out.json" 2>/dev/null
  RET=$?
  check "drift error: missing baseline exit=1" "1" "$RET"
else
  skip "drift error: missing baseline exit=1"
fi

# =============================================================================
# 199. Resample oversample
# =============================================================================
echo ""
echo "=== 199. Resample oversample ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_resample_over
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
label,value
A,1
A,2
B,3
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "resample", "column": "label", "strategy": "oversample", "seed": 0}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  LINES=$(tail -n +2 "$DIR/out.csv" | wc -l | tr -d ' ')
  check "resample over: 4 data rows" "4" "$LINES"

  ROW1=$(tail -n +2 "$DIR/out.csv" | sed -n '1p')
  check "resample over: row1=A,1" "A,1" "$ROW1"

  ROW2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  check "resample over: row2=A,2" "A,2" "$ROW2"

  ROW3=$(tail -n +2 "$DIR/out.csv" | sed -n '3p')
  check "resample over: row3=B,3" "B,3" "$ROW3"

  ROW4=$(tail -n +2 "$DIR/out.csv" | sed -n '4p')
  check "resample over: row4=B,3 (copy)" "B,3" "$ROW4"
else
  skip "resample over: 4 data rows"
  skip "resample over: row1=A,1"
  skip "resample over: row2=A,2"
  skip "resample over: row3=B,3"
  skip "resample over: row4=B,3 (copy)"
fi

# =============================================================================
# 200. Resample undersample
# =============================================================================
echo ""
echo "=== 200. Resample undersample ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_resample_under
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
label,value
A,1
A,2
A,3
B,4
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "resample", "column": "label", "strategy": "undersample", "seed": 42}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  LINES=$(tail -n +2 "$DIR/out.csv" | wc -l | tr -d ' ')
  check "resample under: 2 data rows" "2" "$LINES"

  HEADER=$(head -1 "$DIR/out.csv")
  check "resample under: header" "label,value" "$HEADER"

  ROW2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  check "resample under: last row=B,4" "B,4" "$ROW2"
else
  skip "resample under: 2 data rows"
  skip "resample under: header"
  skip "resample under: last row=B,4"
fi

# =============================================================================
# 201. Watermark basic
# =============================================================================
echo ""
echo "=== 201. Watermark basic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_watermark
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,name
1,Alice
2,Bob
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "watermark", "columns": ["id", "name"], "key": "secret", "as": "wmark"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv")
  check "watermark: header" "id,name,wmark" "$HEADER"

  WM1=$(tail -n +2 "$DIR/out.csv" | sed -n '1p' | cut -d',' -f3)
  WM_LEN=$(echo -n "$WM1" | wc -c | tr -d ' ')
  check "watermark: wm length=16" "16" "$WM_LEN"

  WM_HEX=$(echo "$WM1" | grep -cE '^[0-9a-f]{16}$')
  check "watermark: wm is hex" "1" "$WM_HEX"
else
  skip "watermark: header"
  skip "watermark: wm length=16"
  skip "watermark: wm is hex"
fi

# =============================================================================
# 202. Watermark determinism
# =============================================================================
echo ""
echo "=== 202. Watermark determinism ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_watermark_det
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,name
1,Alice
1,Alice
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "watermark", "columns": ["id", "name"], "key": "mykey", "as": "wm"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  WM1=$(tail -n +2 "$DIR/out.csv" | sed -n '1p' | cut -d',' -f3)
  WM2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p' | cut -d',' -f3)
  check "watermark det: same input same output" "$WM1" "$WM2"
else
  skip "watermark det: same input same output"
fi

# =============================================================================
# 203. Pipeline drift step
# =============================================================================
echo ""
echo "=== 203. Pipeline drift step ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pipe_drift
  mkdir -p "$DIR"

  cat > "$DIR/base.csv" << 'EOF'
x
1.0
2.0
3.0
EOF

  cat > "$DIR/cur.csv" << 'EOF'
x
1.0
2.0
3.0
EOF

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 0,
  "steps": [
    {"type": "drift", "baseline": "/tmp/test_pipe_drift/base.csv", "current": "/tmp/test_pipe_drift/cur.csv", "output": "/tmp/test_pipe_drift/drift_out.json"}
  ]
}
EOF

  $DPIPE pipeline --config "$DIR/pipeline.json" 2>/dev/null
  RET=$?
  check "pipeline drift: exit code 0" "0" "$RET"

  TOTAL_D=$(python3 -c "import json; d=json.load(open('$DIR/drift_out.json')); print(d['summary']['total_drifts'])")
  check "pipeline drift: no drifts" "0" "$TOTAL_D"
else
  skip "pipeline drift: exit code 0"
  skip "pipeline drift: no drifts"
fi

# =============================================================================
# 204. Drift: type changed detection
# =============================================================================
echo ""
echo "=== 204. Drift type changed ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_drift_typechg
  mkdir -p "$DIR"

  cat > "$DIR/baseline.csv" << 'EOF'
val
1
2
3
EOF

  cat > "$DIR/current.csv" << 'EOF'
val
abc
def
ghi
EOF

  $DPIPE drift --baseline "$DIR/baseline.csv" --current "$DIR/current.csv" --output "$DIR/drift.json" 2>/dev/null

  D_TYPE=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['drifts'][0]['drift_type'])")
  check "drift type changed: drift_type=type_changed" "type_changed" "$D_TYPE"

  DETAIL=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['drifts'][0]['detail'])")
  check "drift type changed: detail" "type changed from int to string" "$DETAIL"
else
  skip "drift type changed: drift_type=type_changed"
  skip "drift type changed: detail"
fi

# =============================================================================
# 205. Drift: null rate and unique ratio change
# =============================================================================
echo ""
echo "=== 205. Drift null rate and unique ratio ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_drift_nulluniq
  mkdir -p "$DIR"

  cat > "$DIR/baseline.csv" << 'EOF'
x,y
10,a
20,b
30,c
40,d
EOF

  cat > "$DIR/current.csv" << 'EOF'
x,y
25,a
,b
25,c
,d
EOF

  $DPIPE drift --baseline "$DIR/baseline.csv" --current "$DIR/current.csv" --output "$DIR/drift.json" 2>/dev/null

  TOTAL_D=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['summary']['total_drifts'])")
  check "drift null+uniq: total_drifts=2" "2" "$TOTAL_D"

  D0_TYPE=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['drifts'][0]['drift_type'])")
  check "drift null+uniq: first=null_rate_change" "null_rate_change" "$D0_TYPE"

  D1_TYPE=$(python3 -c "import json; d=json.load(open('$DIR/drift.json')); print(d['drifts'][1]['drift_type'])")
  check "drift null+uniq: second=unique_ratio_change" "unique_ratio_change" "$D1_TYPE"
else
  skip "drift null+uniq: total_drifts=2"
  skip "drift null+uniq: first=null_rate_change"
  skip "drift null+uniq: second=unique_ratio_change"
fi

# =============================================================================
# 206. Resample oversample multi-group
# =============================================================================
echo ""
echo "=== 206. Resample oversample multi ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_resample_over2
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
label,value
C,7
C,8
C,9
A,1
B,4
B,5
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "resample", "column": "label", "strategy": "oversample", "seed": 0}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  LINES=$(tail -n +2 "$DIR/out.csv" | wc -l | tr -d ' ')
  check "resample over multi: 9 rows" "9" "$LINES"

  ROW1=$(tail -n +2 "$DIR/out.csv" | sed -n '1p')
  check "resample over multi: row1=A,1" "A,1" "$ROW1"

  ROW2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p')
  check "resample over multi: row2=A,1 copy" "A,1" "$ROW2"

  ROW3=$(tail -n +2 "$DIR/out.csv" | sed -n '3p')
  check "resample over multi: row3=A,1 copy2" "A,1" "$ROW3"

  ROW4=$(tail -n +2 "$DIR/out.csv" | sed -n '4p')
  check "resample over multi: row4=B,4" "B,4" "$ROW4"
else
  skip "resample over multi: 9 rows"
  skip "resample over multi: row1=A,1"
  skip "resample over multi: row2=A,1 copy"
  skip "resample over multi: row3=A,1 copy2"
  skip "resample over multi: row4=B,4"
fi

# =============================================================================
# 207. Resample missing column error
# =============================================================================
echo ""
echo "=== 207. Resample error ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_resample_err
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
a,b
1,2
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "resample", "column": "missing", "strategy": "oversample", "seed": 0}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null
  RET=$?
  check "resample error: exit code 1" "1" "$RET"
else
  skip "resample error: exit code 1"
fi

# =============================================================================
# 208. Watermark missing column error
# =============================================================================
echo ""
echo "=== 208. Watermark error ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_wm_err
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
a,b
1,2
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "watermark", "columns": ["a", "missing"], "key": "k", "as": "wm"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null
  RET=$?
  check "watermark error: exit code 1" "1" "$RET"
else
  skip "watermark error: exit code 1"
fi

# =============================================================================
# 209. Drift with custom threshold
# =============================================================================
echo ""
echo "=== 209. Drift custom threshold ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_drift_thresh
  mkdir -p "$DIR"

  cat > "$DIR/baseline.csv" << 'EOF'
x
0.0
100.0
EOF

  cat > "$DIR/current.csv" << 'EOF'
x
0.0
200.0
EOF

  $DPIPE drift --baseline "$DIR/baseline.csv" --current "$DIR/current.csv" --output "$DIR/drift_low.json" --threshold 0.1 2>/dev/null
  D_LOW=$(python3 -c "import json; d=json.load(open('$DIR/drift_low.json')); print(d['summary']['total_drifts'])")

  $DPIPE drift --baseline "$DIR/baseline.csv" --current "$DIR/current.csv" --output "$DIR/drift_high.json" --threshold 10 2>/dev/null
  D_HIGH=$(python3 -c "import json; d=json.load(open('$DIR/drift_high.json')); print(d['summary']['total_drifts'])")

  check "drift thresh: low thresh has drifts" "2" "$D_LOW"
  check "drift thresh: high thresh no drifts" "0" "$D_HIGH"
else
  skip "drift thresh: low thresh has drifts"
  skip "drift thresh: high thresh no drifts"
fi

# =============================================================================
# 210. Fill linear: no anchors remain empty
# =============================================================================
echo ""
echo "=== 210. Fill linear no anchors ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_fill_no_anchors
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,val
1,
2,abc
3,
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "fill", "columns": ["val"], "strategy": "linear"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 0 2>/dev/null

  V1=$(tail -n +2 "$DIR/out.csv" | sed -n '1p' | cut -d',' -f2)
  check "fill no anchors: row1 empty" "" "$V1"

  V3=$(tail -n +2 "$DIR/out.csv" | sed -n '3p' | cut -d',' -f2)
  check "fill no anchors: row3 empty" "" "$V3"
else
  skip "fill no anchors: row1 empty"
  skip "fill no anchors: row3 empty"
fi



# =============================================================================
# 211. Validate - type check
# =============================================================================
echo ""
echo "=== 211. Validate type check ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_validate_type
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,age
1,25
2,abc
3,30
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": {
    "age": {
      "type": "int"
    }
  }
}
EOF

  $DPIPE validate --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/report.json" 2>/dev/null
  RET=$?
  check "validate type: exit code 0" "0" "$RET"

  VALID=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['valid'])")
  check "validate type: valid is False" "False" "$VALID"

  RULE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['rule'])")
  check "validate type: violation rule is type" "type" "$RULE"

  VALUE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['value'])")
  check "validate type: violation value is abc" "abc" "$VALUE"

  MSG=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['message'])")
  check "validate type: violation message" 'expected int, got "abc"' "$MSG"

  ROW=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['row'])")
  check "validate type: violation row is 2" "2" "$ROW"

  TOTAL_V=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['total_violations'])")
  check "validate type: total violations is 1" "1" "$TOTAL_V"
else
  skip "validate type: exit code 0"
  skip "validate type: valid is False"
  skip "validate type: violation rule is type"
  skip "validate type: violation value is abc"
  skip "validate type: violation message"
  skip "validate type: violation row is 2"
  skip "validate type: total violations is 1"
fi

# =============================================================================
# 212. Validate - required
# =============================================================================
echo ""
echo "=== 212. Validate required ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_validate_required
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,name
1,Alice
2,
3,Charlie
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": {
    "name": {
      "type": "string",
      "required": true
    }
  }
}
EOF

  $DPIPE validate --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/report.json" 2>/dev/null

  VALID=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['valid'])")
  check "validate required: valid is False" "False" "$VALID"

  RULE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['rule'])")
  check "validate required: violation rule is required" "required" "$RULE"

  VALUE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['value'])")
  check "validate required: violation value is None" "None" "$VALUE"

  MSG=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['message'])")
  check "validate required: message is value is required" "value is required" "$MSG"

  ROW=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['row'])")
  check "validate required: violation row is 2" "2" "$ROW"
else
  skip "validate required: valid is False"
  skip "validate required: violation rule is required"
  skip "validate required: violation value is None"
  skip "validate required: message is value is required"
  skip "validate required: violation row is 2"
fi

# =============================================================================
# 213. Validate - min/max
# =============================================================================
echo ""
echo "=== 213. Validate min max ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_validate_minmax
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,score
1,50
2,-5
3,80
4,150
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": {
    "score": {
      "type": "int",
      "min": 0,
      "max": 100
    }
  }
}
EOF

  $DPIPE validate --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/report.json" 2>/dev/null

  VALID=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['valid'])")
  check "validate minmax: valid is False" "False" "$VALID"

  TOTAL_V=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['total_violations'])")
  check "validate minmax: total violations is 2" "2" "$TOTAL_V"

  # First violation: -5 is below minimum 0
  RULE0=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['rule'])")
  check "validate minmax: first violation rule is min" "min" "$RULE0"

  MSG0=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['message'])")
  check "validate minmax: first violation message" "value -5 is below minimum 0" "$MSG0"

  ROW0=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['row'])")
  check "validate minmax: first violation row is 2" "2" "$ROW0"

  # Second violation: 150 exceeds maximum 100
  RULE1=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][1]['rule'])")
  check "validate minmax: second violation rule is max" "max" "$RULE1"

  MSG1=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][1]['message'])")
  check "validate minmax: second violation message" "value 150 exceeds maximum 100" "$MSG1"

  ROW1=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][1]['row'])")
  check "validate minmax: second violation row is 4" "4" "$ROW1"
else
  skip "validate minmax: valid is False"
  skip "validate minmax: total violations is 2"
  skip "validate minmax: first violation rule is min"
  skip "validate minmax: first violation message"
  skip "validate minmax: first violation row is 2"
  skip "validate minmax: second violation rule is max"
  skip "validate minmax: second violation message"
  skip "validate minmax: second violation row is 4"
fi

# =============================================================================
# 214. Validate - pattern
# =============================================================================
echo ""
echo "=== 214. Validate pattern ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_validate_pattern
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,name
1,Hello
2,hello
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": {
    "name": {
      "type": "string",
      "pattern": "^[A-Z]"
    }
  }
}
EOF

  $DPIPE validate --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/report.json" 2>/dev/null

  VALID=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['valid'])")
  check "validate pattern: valid is False" "False" "$VALID"

  TOTAL_V=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['total_violations'])")
  check "validate pattern: total violations is 1" "1" "$TOTAL_V"

  RULE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['rule'])")
  check "validate pattern: violation rule is pattern" "pattern" "$RULE"

  VALUE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['value'])")
  check "validate pattern: violation value is hello" "hello" "$VALUE"

  MSG=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['message'])")
  check "validate pattern: violation message" 'value "hello" does not match pattern ^[A-Z]' "$MSG"

  ROW=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['row'])")
  check "validate pattern: violation row is 2" "2" "$ROW"
else
  skip "validate pattern: valid is False"
  skip "validate pattern: total violations is 1"
  skip "validate pattern: violation rule is pattern"
  skip "validate pattern: violation value is hello"
  skip "validate pattern: violation message"
  skip "validate pattern: violation row is 2"
fi

# =============================================================================
# 215. Validate - enum
# =============================================================================
echo ""
echo "=== 215. Validate enum ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_validate_enum
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,status
1,A
2,B
3,D
4,C
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": {
    "status": {
      "type": "string",
      "enum": ["A", "B", "C"]
    }
  }
}
EOF

  $DPIPE validate --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/report.json" 2>/dev/null

  VALID=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['valid'])")
  check "validate enum: valid is False" "False" "$VALID"

  TOTAL_V=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['total_violations'])")
  check "validate enum: total violations is 1" "1" "$TOTAL_V"

  RULE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['rule'])")
  check "validate enum: violation rule is enum" "enum" "$RULE"

  VALUE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['value'])")
  check "validate enum: violation value is D" "D" "$VALUE"

  MSG=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['message'])")
  check "validate enum: violation message" 'value "D" is not in allowed values [A, B, C]' "$MSG"

  ROW=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['row'])")
  check "validate enum: violation row is 3" "3" "$ROW"
else
  skip "validate enum: valid is False"
  skip "validate enum: total violations is 1"
  skip "validate enum: violation rule is enum"
  skip "validate enum: violation value is D"
  skip "validate enum: violation message"
  skip "validate enum: violation row is 3"
fi

# =============================================================================
# 216. Validate - unique
# =============================================================================
echo ""
echo "=== 216. Validate unique ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_validate_unique
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,email
1,a@test.com
2,b@test.com
3,a@test.com
4,c@test.com
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": {
    "email": {
      "type": "string",
      "unique": true
    }
  }
}
EOF

  $DPIPE validate --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/report.json" 2>/dev/null

  VALID=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['valid'])")
  check "validate unique: valid is False" "False" "$VALID"

  TOTAL_V=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['total_violations'])")
  check "validate unique: total violations is 1" "1" "$TOTAL_V"

  RULE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['rule'])")
  check "validate unique: violation rule is unique" "unique" "$RULE"

  VALUE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['value'])")
  check "validate unique: violation value" "a@test.com" "$VALUE"

  ROW=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['row'])")
  check "validate unique: violation row is None" "None" "$ROW"

  MSG=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['message'])")
  check "validate unique: violation message" 'duplicate value "a@test.com" (first at row 1, repeated at row 3)' "$MSG"
else
  skip "validate unique: valid is False"
  skip "validate unique: total violations is 1"
  skip "validate unique: violation rule is unique"
  skip "validate unique: violation value"
  skip "validate unique: violation row is None"
  skip "validate unique: violation message"
fi

# =============================================================================
# 217. Validate - column_missing
# =============================================================================
echo ""
echo "=== 217. Validate column missing ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_validate_colmissing
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,name
1,Alice
2,Bob
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": {
    "name": {
      "type": "string"
    },
    "xyz": {
      "type": "int"
    }
  }
}
EOF

  $DPIPE validate --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/report.json" 2>/dev/null

  VALID=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['valid'])")
  check "validate colmissing: valid is False" "False" "$VALID"

  TOTAL_V=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['total_violations'])")
  check "validate colmissing: total violations is 1" "1" "$TOTAL_V"

  RULE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['rule'])")
  check "validate colmissing: violation rule is column_missing" "column_missing" "$RULE"

  ROW=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['row'])")
  check "validate colmissing: violation row is None" "None" "$ROW"

  MSG=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['message'])")
  check "validate colmissing: violation message" 'column "xyz" defined in schema but missing from data' "$MSG"

  COLS_CHECKED=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['columns_checked'])")
  check "validate colmissing: columns_checked is 1" "1" "$COLS_CHECKED"
else
  skip "validate colmissing: valid is False"
  skip "validate colmissing: total violations is 1"
  skip "validate colmissing: violation rule is column_missing"
  skip "validate colmissing: violation row is None"
  skip "validate colmissing: violation message"
  skip "validate colmissing: columns_checked is 1"
fi

# =============================================================================
# 218. Validate - strict mode
# =============================================================================
echo ""
echo "=== 218. Validate strict mode ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_validate_strict
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,name,extra
1,Alice,foo
2,Bob,bar
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": {
    "id": {
      "type": "int"
    },
    "name": {
      "type": "string"
    }
  },
  "strict": true
}
EOF

  $DPIPE validate --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/report.json" 2>/dev/null

  VALID=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['valid'])")
  check "validate strict: valid is False" "False" "$VALID"

  TOTAL_V=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['total_violations'])")
  check "validate strict: total violations is 1" "1" "$TOTAL_V"

  RULE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['rule'])")
  check "validate strict: violation rule is strict" "strict" "$RULE"

  COL=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['column'])")
  check "validate strict: violation column is extra" "extra" "$COL"

  MSG=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['message'])")
  check "validate strict: violation message" 'column "extra" not defined in schema' "$MSG"

  VALUE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['value'])")
  check "validate strict: violation value is None" "None" "$VALUE"
else
  skip "validate strict: valid is False"
  skip "validate strict: total violations is 1"
  skip "validate strict: violation rule is strict"
  skip "validate strict: violation column is extra"
  skip "validate strict: violation message"
  skip "validate strict: violation value is None"
fi

# =============================================================================
# 219. Validate - valid file
# =============================================================================
echo ""
echo "=== 219. Validate valid file ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_validate_valid
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,name,age
1,Alice,25
2,Bob,30
3,Charlie,35
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": {
    "id": {
      "type": "int",
      "required": true,
      "min": 1
    },
    "name": {
      "type": "string",
      "required": true
    },
    "age": {
      "type": "int",
      "min": 0,
      "max": 150
    }
  }
}
EOF

  $DPIPE validate --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/report.json" 2>/dev/null

  VALID=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['valid'])")
  check "validate valid: valid is True" "True" "$VALID"

  TOTAL_V=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['total_violations'])")
  check "validate valid: total violations is 0" "0" "$TOTAL_V"

  ROWS_CHECKED=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['rows_checked'])")
  check "validate valid: rows_checked is 3" "3" "$ROWS_CHECKED"

  COLS_CHECKED=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['columns_checked'])")
  check "validate valid: columns_checked is 3" "3" "$COLS_CHECKED"

  VIO_LEN=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(len(d['violations']))")
  check "validate valid: violations array is empty" "0" "$VIO_LEN"
else
  skip "validate valid: valid is True"
  skip "validate valid: total violations is 0"
  skip "validate valid: rows_checked is 3"
  skip "validate valid: columns_checked is 3"
  skip "validate valid: violations array is empty"
fi

# =============================================================================
# 220. Validate - missing input file
# =============================================================================
echo ""
echo "=== 220. Validate missing input ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_validate_missinput
  mkdir -p "$DIR"

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": {
    "id": {"type": "int"}
  }
}
EOF

  ERR=$($DPIPE validate --input "$DIR/nonexistent.csv" --schema "$DIR/schema.json" --output "$DIR/report.json" 2>&1)
  RET=$?
  check "validate missing input: exit code 1" "1" "$RET"
  check_contains "validate missing input: error message" "ERROR" "$ERR"
else
  skip "validate missing input: exit code 1"
  skip "validate missing input: error message"
fi

# =============================================================================
# 221. Validate - invalid schema
# =============================================================================
echo ""
echo "=== 221. Validate invalid schema ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_validate_badschema
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,name
1,Alice
EOF

  cat > "$DIR/schema.json" << 'EOF'
{this is not valid json
EOF

  ERR=$($DPIPE validate --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/report.json" 2>&1)
  RET=$?
  check "validate invalid schema: exit code 1" "1" "$RET"
  check_contains "validate invalid schema: error mentions invalid schema" "invalid schema" "$ERR"
else
  skip "validate invalid schema: exit code 1"
  skip "validate invalid schema: error mentions invalid schema"
fi

# =============================================================================
# 222. Validate - multiple violations ordering
# =============================================================================
echo ""
echo "=== 222. Validate violation ordering ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_validate_ordering
  mkdir -p "$DIR"

  # CSV with columns: id, age, name
  # Schema defines age (int, required, min=0, max=100) and name (string, required)
  # Row 1: valid
  # Row 2: age=abc (type violation), name="" (required violation)
  # Row 3: age=-5 (min violation)
  # Row 4: age=150 (max violation)
  cat > "$DIR/data.csv" << 'EOF'
id,age,name
1,25,Alice
2,abc,
3,-5,Charlie
4,150,Diana
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": {
    "age": {
      "type": "int",
      "required": true,
      "min": 0,
      "max": 100
    },
    "name": {
      "type": "string",
      "required": true
    }
  }
}
EOF

  $DPIPE validate --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/report.json" 2>/dev/null

  VALID=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['valid'])")
  check "validate ordering: valid is False" "False" "$VALID"

  # Violations should be ordered: age column first (CSV header order), then name column
  # Within age: type (row 2), then min (row 3), then max (row 4)
  # Within name: required (row 2)
  TOTAL_V=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['total_violations'])")
  check "validate ordering: total violations is 4" "4" "$TOTAL_V"

  # Violation 0: age, type, row 2
  V0_COL=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['column'])")
  V0_RULE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['rule'])")
  check "validate ordering: v0 column is age" "age" "$V0_COL"
  check "validate ordering: v0 rule is type" "type" "$V0_RULE"

  # Violation 1: age, min, row 3
  V1_COL=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][1]['column'])")
  V1_RULE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][1]['rule'])")
  check "validate ordering: v1 column is age" "age" "$V1_COL"
  check "validate ordering: v1 rule is min" "min" "$V1_RULE"

  # Violation 2: age, max, row 4
  V2_COL=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][2]['column'])")
  V2_RULE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][2]['rule'])")
  check "validate ordering: v2 column is age" "age" "$V2_COL"
  check "validate ordering: v2 rule is max" "max" "$V2_RULE"

  # Violation 3: name, required, row 2
  V3_COL=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][3]['column'])")
  V3_RULE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][3]['rule'])")
  check "validate ordering: v3 column is name" "name" "$V3_COL"
  check "validate ordering: v3 rule is required" "required" "$V3_RULE"
else
  skip "validate ordering: valid is False"
  skip "validate ordering: total violations is 4"
  skip "validate ordering: v0 column is age"
  skip "validate ordering: v0 rule is type"
  skip "validate ordering: v1 column is age"
  skip "validate ordering: v1 rule is min"
  skip "validate ordering: v2 column is age"
  skip "validate ordering: v2 rule is max"
  skip "validate ordering: v3 column is name"
  skip "validate ordering: v3 rule is required"
fi


# =============================================================================
# 223. Crossjoin basic
# =============================================================================
echo ""
echo "=== 223. Crossjoin basic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_crossjoin_basic
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
a
1
2
EOF

  cat > "$DIR/right.csv" << 'EOF'
b
3
4
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "crossjoin", "right": "/tmp/test_crossjoin_basic/right.csv"}]
EOF

  $DPIPE transform --input "$DIR/left.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv" 2>/dev/null)
  check "crossjoin basic: header is a,b" "a,b" "$HEADER"

  ROW_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "crossjoin basic: row count is 4" "4" "$ROW_COUNT"

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "crossjoin basic: row 1 is 1,3" "1,3" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "crossjoin basic: row 2 is 1,4" "1,4" "$ROW2"

  ROW3=$(sed -n '4p' "$DIR/out.csv")
  check "crossjoin basic: row 3 is 2,3" "2,3" "$ROW3"

  ROW4=$(sed -n '5p' "$DIR/out.csv")
  check "crossjoin basic: row 4 is 2,4" "2,4" "$ROW4"
else
  skip "crossjoin basic: header is a,b"
  skip "crossjoin basic: row count is 4"
  skip "crossjoin basic: row 1 is 1,3"
  skip "crossjoin basic: row 2 is 1,4"
  skip "crossjoin basic: row 3 is 2,3"
  skip "crossjoin basic: row 4 is 2,4"
fi

# =============================================================================
# 224. Crossjoin with columns selection
# =============================================================================
echo ""
echo "=== 224. Crossjoin with columns ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_crossjoin_cols
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
a
1
EOF

  cat > "$DIR/right.csv" << 'EOF'
b,c
3,4
5,6
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "crossjoin", "right": "/tmp/test_crossjoin_cols/right.csv", "columns": ["c"]}]
EOF

  $DPIPE transform --input "$DIR/left.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv" 2>/dev/null)
  check "crossjoin cols: header is a,c" "a,c" "$HEADER"

  ROW_COUNT=$(tail -n +2 "$DIR/out.csv" 2>/dev/null | wc -l | tr -d ' ')
  check "crossjoin cols: row count is 2" "2" "$ROW_COUNT"

  ROW1=$(sed -n '2p' "$DIR/out.csv")
  check "crossjoin cols: row 1 is 1,4" "1,4" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv")
  check "crossjoin cols: row 2 is 1,6" "1,6" "$ROW2"
else
  skip "crossjoin cols: header is a,c"
  skip "crossjoin cols: row count is 2"
  skip "crossjoin cols: row 1 is 1,4"
  skip "crossjoin cols: row 2 is 1,6"
fi

# =============================================================================
# 225. Crossjoin file not found
# =============================================================================
echo ""
echo "=== 225. Crossjoin file not found ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_crossjoin_fnf
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
a
1
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "crossjoin", "right": "/tmp/test_crossjoin_fnf/nonexistent.csv"}]
EOF

  ERR=$($DPIPE transform --input "$DIR/left.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>&1)
  RET=$?
  check "crossjoin fnf: exit code 1" "1" "$RET"
  check_contains "crossjoin fnf: error message" "file not found" "$ERR"
else
  skip "crossjoin fnf: exit code 1"
  skip "crossjoin fnf: error message"
fi

# =============================================================================
# 226. Crossjoin column not found
# =============================================================================
echo ""
echo "=== 226. Crossjoin column not found ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_crossjoin_colnf
  mkdir -p "$DIR"

  cat > "$DIR/left.csv" << 'EOF'
a
1
EOF

  cat > "$DIR/right.csv" << 'EOF'
b,c
3,4
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "crossjoin", "right": "/tmp/test_crossjoin_colnf/right.csv", "columns": ["nonexist"]}]
EOF

  ERR=$($DPIPE transform --input "$DIR/left.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>&1)
  RET=$?
  check "crossjoin colnf: exit code 1" "1" "$RET"
  check_contains "crossjoin colnf: error about column" "column nonexist not found" "$ERR"
else
  skip "crossjoin colnf: exit code 1"
  skip "crossjoin colnf: error about column"
fi

# =============================================================================
# 227. Checkpoint row_hash
# =============================================================================
echo ""
echo "=== 227. Checkpoint row_hash ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_checkpoint_hash
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
a,b
1,2
3,4
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "checkpoint", "algorithm": "row_hash", "as": "ckpt"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv" 2>/dev/null)
  check "checkpoint hash: header is a,b,ckpt" "a,b,ckpt" "$HEADER"

  # Check ckpt column exists and is 8 hex chars
  CKPT1=$(tail -n +2 "$DIR/out.csv" | head -1 | rev | cut -d',' -f1 | rev)
  CKPT1_LEN=$(echo -n "$CKPT1" | wc -c | tr -d ' ')
  check "checkpoint hash: ckpt1 length is 8" "8" "$CKPT1_LEN"

  CKPT1_HEX=$(echo "$CKPT1" | grep -cE '^[0-9a-f]{8}$')
  check "checkpoint hash: ckpt1 is hex" "1" "$CKPT1_HEX"

  CKPT2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p' | rev | cut -d',' -f1 | rev)
  CKPT2_LEN=$(echo -n "$CKPT2" | wc -c | tr -d ' ')
  check "checkpoint hash: ckpt2 length is 8" "8" "$CKPT2_LEN"

  # Verify determinism: run again and check same hash
  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out2.csv" --seed 42 2>/dev/null
  CKPT1_B=$(tail -n +2 "$DIR/out2.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "checkpoint hash: deterministic same hash" "$CKPT1" "$CKPT1_B"
else
  skip "checkpoint hash: header is a,b,ckpt"
  skip "checkpoint hash: ckpt1 length is 8"
  skip "checkpoint hash: ckpt1 is hex"
  skip "checkpoint hash: ckpt2 length is 8"
  skip "checkpoint hash: deterministic same hash"
fi

# =============================================================================
# 228. Checkpoint row_number
# =============================================================================
echo ""
echo "=== 228. Checkpoint row_number ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_checkpoint_rownum
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
x
10
20
30
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "checkpoint", "algorithm": "row_number", "as": "rn"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  HEADER=$(head -1 "$DIR/out.csv" 2>/dev/null)
  check "checkpoint rownum: header is x,rn" "x,rn" "$HEADER"

  RN1=$(tail -n +2 "$DIR/out.csv" | head -1 | rev | cut -d',' -f1 | rev)
  check "checkpoint rownum: row 1 rn=1" "1" "$RN1"

  RN2=$(tail -n +2 "$DIR/out.csv" | sed -n '2p' | rev | cut -d',' -f1 | rev)
  check "checkpoint rownum: row 2 rn=2" "2" "$RN2"

  RN3=$(tail -n +2 "$DIR/out.csv" | sed -n '3p' | rev | cut -d',' -f1 | rev)
  check "checkpoint rownum: row 3 rn=3" "3" "$RN3"
else
  skip "checkpoint rownum: header is x,rn"
  skip "checkpoint rownum: row 1 rn=1"
  skip "checkpoint rownum: row 2 rn=2"
  skip "checkpoint rownum: row 3 rn=3"
fi

# =============================================================================
# 229. Pipeline validate step
# =============================================================================
echo ""
echo "=== 229. Pipeline validate step ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pipeline_validate_r4
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
id,age,name
1,25,Alice
2,30,Bob
3,abc,Charlie
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": {
    "id": {
      "type": "int"
    },
    "age": {
      "type": "int"
    },
    "name": {
      "type": "string"
    }
  }
}
EOF

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "steps": [
    {"type": "validate", "input": "/tmp/test_pipeline_validate_r4/data.csv", "schema": "/tmp/test_pipeline_validate_r4/schema.json", "output": "/tmp/test_pipeline_validate_r4/report.json"}
  ]
}
EOF

  $DPIPE pipeline --config "$DIR/pipeline.json" 2>/dev/null
  RET=$?
  check "pipeline validate r4: exit code 0" "0" "$RET"

  if [ -f "$DIR/report.json" ]; then
    check "pipeline validate r4: report file exists" "1" "1"

    VALID=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['valid'])")
    check "pipeline validate r4: valid is False" "False" "$VALID"

    TOTAL_V=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['total_violations'])")
    check "pipeline validate r4: has 1 violation" "1" "$TOTAL_V"

    RULE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['rule'])")
    check "pipeline validate r4: violation rule is type" "type" "$RULE"
  else
    check "pipeline validate r4: report file exists" "1" "0"
    skip "pipeline validate r4: valid is False"
    skip "pipeline validate r4: has 1 violation"
    skip "pipeline validate r4: violation rule is type"
  fi
else
  skip "pipeline validate r4: exit code 0"
  skip "pipeline validate r4: report file exists"
  skip "pipeline validate r4: valid is False"
  skip "pipeline validate r4: has 1 violation"
  skip "pipeline validate r4: violation rule is type"
fi

# =============================================================================
# 230. Validate float type check
# =============================================================================
echo ""
echo "=== 230. Validate float type check ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_validate_float
  mkdir -p "$DIR"

  cat > "$DIR/data.csv" << 'EOF'
score
1.5
2.7
abc
EOF

  cat > "$DIR/schema.json" << 'EOF'
{
  "columns": {
    "score": {
      "type": "float"
    }
  }
}
EOF

  $DPIPE validate --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/report.json" 2>/dev/null

  VALID=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['valid'])")
  check "validate float: valid is False" "False" "$VALID"

  TOTAL_V=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['summary']['total_violations'])")
  check "validate float: total violations is 1" "1" "$TOTAL_V"

  RULE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['rule'])")
  check "validate float: violation rule is type" "type" "$RULE"

  ROW=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['row'])")
  check "validate float: violation row is 3" "3" "$ROW"

  VALUE=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['value'])")
  check "validate float: violation value is abc" "abc" "$VALUE"

  MSG=$(python3 -c "import json; d=json.load(open('$DIR/report.json')); print(d['violations'][0]['message'])")
  check "validate float: violation message" 'expected float, got "abc"' "$MSG"
else
  skip "validate float: valid is False"
  skip "validate float: total violations is 1"
  skip "validate float: violation rule is type"
  skip "validate float: violation row is 3"
  skip "validate float: violation value is abc"
  skip "validate float: violation message"
fi


# =============================================================================
# 231. Lineage basic: 2-step pipeline (ingest -> transform)
# =============================================================================
echo ""
echo "=== 231. Lineage basic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_lineage_basic
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "ingest", "file": "data.csv", "output": "clean.csv"},
    {"type": "transform", "input": "clean.csv", "recipe": "recipe.json", "output": "final.csv"}
  ]
}
EOF

  $DPIPE lineage --config "$DIR/pipeline.json" --output "$DIR/lineage.json" 2>/dev/null
  LINEAGE_EXIT=$?
  check "lineage basic: exit code 0" "0" "$LINEAGE_EXIT"

  NODE_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(len(d['nodes']))" 2>/dev/null)
  check "lineage basic: node count is 4" "4" "$NODE_COUNT"

  EDGE_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(len(d['edges']))" 2>/dev/null)
  check "lineage basic: edge count is 3" "3" "$EDGE_COUNT"

  STEP_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(len(d['steps']))" 2>/dev/null)
  check "lineage basic: step count is 2" "2" "$STEP_COUNT"

  # Check nodes are sorted by id
  FIRST_NODE=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(d['nodes'][0]['id'])" 2>/dev/null)
  check "lineage basic: first node is clean.csv" "clean.csv" "$FIRST_NODE"

  # Check clean.csv is produced_by step 1
  PRODUCED=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(d['nodes'][0]['produced_by'])" 2>/dev/null)
  check "lineage basic: clean.csv produced_by step 1" "1" "$PRODUCED"

  # Check data.csv produced_by is None
  DATA_PRODUCED=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); nodes={n['id']:n for n in d['nodes']}; print(nodes['data.csv']['produced_by'])" 2>/dev/null)
  check "lineage basic: data.csv produced_by is null" "None" "$DATA_PRODUCED"

  # Check step 1 type
  STEP1_TYPE=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(d['steps'][0]['type'])" 2>/dev/null)
  check "lineage basic: step 1 type is ingest" "ingest" "$STEP1_TYPE"

  # Check step 2 inputs
  STEP2_INPUTS=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(','.join(sorted(d['steps'][1]['inputs'])))" 2>/dev/null)
  check "lineage basic: step 2 inputs" "clean.csv,recipe.json" "$STEP2_INPUTS"
else
  skip "lineage basic: exit code 0"
  skip "lineage basic: node count is 4"
  skip "lineage basic: edge count is 3"
  skip "lineage basic: step count is 2"
  skip "lineage basic: first node is clean.csv"
  skip "lineage basic: clean.csv produced_by step 1"
  skip "lineage basic: data.csv produced_by is null"
  skip "lineage basic: step 1 type is ingest"
  skip "lineage basic: step 2 inputs"
fi

# =============================================================================
# 232. Lineage with profile: 3-step pipeline
# =============================================================================
echo ""
echo "=== 232. Lineage with profile ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_lineage_profile
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "ingest", "file": "raw.csv", "output": "clean.csv"},
    {"type": "transform", "input": "clean.csv", "recipe": "recipe.json", "output": "transformed.csv"},
    {"type": "profile", "input": "transformed.csv", "output": "profile.json"}
  ]
}
EOF

  $DPIPE lineage --config "$DIR/pipeline.json" --output "$DIR/lineage.json" 2>/dev/null

  NODE_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(len(d['nodes']))" 2>/dev/null)
  check "lineage profile: node count is 5" "5" "$NODE_COUNT"

  EDGE_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(len(d['edges']))" 2>/dev/null)
  check "lineage profile: edge count is 4" "4" "$EDGE_COUNT"

  STEP_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(len(d['steps']))" 2>/dev/null)
  check "lineage profile: step count is 3" "3" "$STEP_COUNT"

  # Check profile.json produced_by step 3
  PROFILE_PB=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); nodes={n['id']:n for n in d['nodes']}; print(nodes['profile.json']['produced_by'])" 2>/dev/null)
  check "lineage profile: profile.json produced_by step 3" "3" "$PROFILE_PB"

  # Check step 3 output
  STEP3_OUTPUT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(d['steps'][2]['output'])" 2>/dev/null)
  check "lineage profile: step 3 output is profile.json" "profile.json" "$STEP3_OUTPUT"
else
  skip "lineage profile: node count is 5"
  skip "lineage profile: edge count is 4"
  skip "lineage profile: step count is 3"
  skip "lineage profile: profile.json produced_by step 3"
  skip "lineage profile: step 3 output is profile.json"
fi

# =============================================================================
# 233. Lineage verify step: no output, no edges from it
# =============================================================================
echo ""
echo "=== 233. Lineage verify step ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_lineage_verify
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "ingest", "file": "data.csv", "output": "clean.csv"},
    {"type": "verify", "file": "clean.csv", "checksum": "clean.csv.blake2b"}
  ]
}
EOF

  $DPIPE lineage --config "$DIR/pipeline.json" --output "$DIR/lineage.json" 2>/dev/null

  # verify step has no output, so edges only come from ingest
  EDGE_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(len(d['edges']))" 2>/dev/null)
  check "lineage verify: edge count is 1" "1" "$EDGE_COUNT"

  # Step 2 output should be null
  STEP2_OUTPUT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(d['steps'][1]['output'])" 2>/dev/null)
  check "lineage verify: step 2 output is None" "None" "$STEP2_OUTPUT"

  # verify step has file and checksum inputs
  STEP2_INPUTS=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(','.join(sorted(d['steps'][1]['inputs'])))" 2>/dev/null)
  check "lineage verify: step 2 inputs are file and checksum" "clean.csv,clean.csv.blake2b" "$STEP2_INPUTS"
else
  skip "lineage verify: edge count is 1"
  skip "lineage verify: step 2 output is None"
  skip "lineage verify: step 2 inputs are file and checksum"
fi

# =============================================================================
# 234. Lineage file not found
# =============================================================================
echo ""
echo "=== 234. Lineage file not found ==="
if [ "$BUILD_OK" = "1" ]; then
  LINEAGE_ERR=$($DPIPE lineage --config /tmp/nonexistent_lineage_config.json --output /tmp/lineage_out.json 2>&1)
  LINEAGE_EXIT=$?
  check "lineage file not found: exit code 1" "1" "$LINEAGE_EXIT"
  check_contains "lineage file not found: error message" "file not found" "$LINEAGE_ERR"
else
  skip "lineage file not found: exit code 1"
  skip "lineage file not found: error message"
fi

# =============================================================================
# 235. Lineage invalid JSON
# =============================================================================
echo ""
echo "=== 235. Lineage invalid JSON ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_lineage_invalid
  rm -rf "$DIR"
  mkdir -p "$DIR"

  echo "not valid json{{{" > "$DIR/bad.json"

  LINEAGE_ERR=$($DPIPE lineage --config "$DIR/bad.json" --output "$DIR/lineage.json" 2>&1)
  LINEAGE_EXIT=$?
  check "lineage invalid JSON: exit code 1" "1" "$LINEAGE_EXIT"
  check_contains "lineage invalid JSON: error message" "invalid pipeline config" "$LINEAGE_ERR"
else
  skip "lineage invalid JSON: exit code 1"
  skip "lineage invalid JSON: error message"
fi

# =============================================================================
# 236. BLAKE2b manifest checksums
# =============================================================================
echo ""
echo "=== 236. BLAKE2b manifest ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_blake2b_manifest
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/sample.csv" << 'EOF'
id,value
1,10
2,20
EOF

  $DPIPE manifest --dir "$DIR" --output "$DIR/manifest.json" 2>/dev/null

  # Check manifest has blake2b field
  HAS_BLAKE2B=$(python3 -c "import json; m=json.load(open('$DIR/manifest.json')); print('yes' if 'blake2b' in m['files'][0] else 'no')" 2>/dev/null)
  check "blake2b manifest: has blake2b field" "yes" "$HAS_BLAKE2B"

  # Check checksum is 64 hex chars
  CHECKSUM=$(python3 -c "import json; m=json.load(open('$DIR/manifest.json')); print(m['files'][0]['blake2b'])" 2>/dev/null)
  IS_HEX_64=$(python3 -c "
import re
cs='$CHECKSUM'
print('yes' if re.match(r'^[0-9a-f]{64}$', cs) else 'no')
" 2>/dev/null)
  check "blake2b manifest: checksum is 64 hex chars" "yes" "$IS_HEX_64"

  # Check no sha256 field
  HAS_SHA256=$(python3 -c "import json; m=json.load(open('$DIR/manifest.json')); print('yes' if 'sha256' in m['files'][0] else 'no')" 2>/dev/null)
  check "blake2b manifest: no sha256 field" "no" "$HAS_SHA256"

  # Verify BLAKE2b matches computed value
  COMPUTED=$(python3 -c "
import hashlib
data = open('$DIR/sample.csv','rb').read()
print(hashlib.blake2b(data, digest_size=32).hexdigest())
" 2>/dev/null)
  check "blake2b manifest: checksum matches computed" "$COMPUTED" "$CHECKSUM"
else
  skip "blake2b manifest: has blake2b field"
  skip "blake2b manifest: checksum is 64 hex chars"
  skip "blake2b manifest: no sha256 field"
  skip "blake2b manifest: checksum matches computed"
fi

# =============================================================================
# 237. BLAKE2b verify
# =============================================================================
echo ""
echo "=== 237. BLAKE2b verify ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_blake2b_verify
  rm -rf "$DIR"
  mkdir -p "$DIR"

  echo "test data for blake2b" > "$DIR/testfile.txt"

  # Compute correct BLAKE2b-256 checksum
  python3 -c "
import hashlib
data = open('$DIR/testfile.txt','rb').read()
h = hashlib.blake2b(data, digest_size=32).hexdigest()
open('$DIR/correct.checksum','w').write(h + '\n')
"

  VERIFY_OUT=$($DPIPE verify --file "$DIR/testfile.txt" --checksum "$DIR/correct.checksum" 2>&1)
  VERIFY_EXIT=$?
  check "blake2b verify: correct checksum passes" "0" "$VERIFY_EXIT"
  check_contains "blake2b verify: prints VERIFIED" "VERIFIED" "$VERIFY_OUT"

  # SHA256 checksum should NOT match since verify now uses BLAKE2b
  sha256sum "$DIR/testfile.txt" | awk '{print $1}' > "$DIR/sha256.checksum"
  SHA_OUT=$($DPIPE verify --file "$DIR/testfile.txt" --checksum "$DIR/sha256.checksum" 2>&1)
  SHA_EXIT=$?
  check "blake2b verify: sha256 checksum fails" "1" "$SHA_EXIT"
  check_contains "blake2b verify: sha256 gives MISMATCH" "MISMATCH" "$SHA_OUT"
else
  skip "blake2b verify: correct checksum passes"
  skip "blake2b verify: prints VERIFIED"
  skip "blake2b verify: sha256 checksum fails"
  skip "blake2b verify: sha256 gives MISMATCH"
fi

# =============================================================================
# 238. No .sha256 sidecar after ingest
# =============================================================================
echo ""
echo "=== 238. No .sha256 sidecar ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_no_sidecar
  rm -rf "$DIR"
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

  $DPIPE ingest --input "$DIR/data.csv" --schema "$DIR/schema.json" --output "$DIR/output.csv" 2>/dev/null

  # Verify output was created
  if [ -f "$DIR/output.csv" ]; then
    check "no sidecar: output file exists" "1" "1"
  else
    check "no sidecar: output file exists" "1" "0"
  fi

  # Verify NO .sha256 sidecar was created
  if [ -f "$DIR/output.csv.sha256" ]; then
    check "no sidecar: .sha256 not created after ingest" "0" "1"
  else
    check "no sidecar: .sha256 not created after ingest" "0" "0"
  fi
else
  skip "no sidecar: output file exists"
  skip "no sidecar: .sha256 not created after ingest"
fi

# =============================================================================
# 239. Pipeline with lineage step
# =============================================================================
echo ""
echo "=== 239. Pipeline lineage step ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_pipeline_lineage
  rm -rf "$DIR"
  mkdir -p "$DIR"

  # Create a sub-pipeline config for lineage to analyze
  cat > "$DIR/sub_pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "ingest", "file": "raw.csv", "output": "clean.csv"},
    {"type": "transform", "input": "clean.csv", "recipe": "recipe.json", "output": "final.csv"}
  ]
}
EOF

  # Create the main pipeline that runs lineage
  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "lineage", "config": "/tmp/test_pipeline_lineage/sub_pipeline.json", "output": "/tmp/test_pipeline_lineage/lineage.json"}
  ]
}
EOF

  PIPE_OUT=$($DPIPE pipeline --config "$DIR/pipeline.json" 2>&1)
  PIPE_EXIT=$?
  check "pipeline lineage step: exit code 0" "0" "$PIPE_EXIT"
  check_contains "pipeline lineage step: PIPELINE OK" "PIPELINE OK" "$PIPE_OUT"

  # Verify lineage output was created
  if [ -f "$DIR/lineage.json" ]; then
    LNODE_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(len(d['nodes']))" 2>/dev/null)
    check "pipeline lineage step: lineage has nodes" "4" "$LNODE_COUNT"
  else
    check "pipeline lineage step: lineage file created" "1" "0"
  fi
else
  skip "pipeline lineage step: exit code 0"
  skip "pipeline lineage step: PIPELINE OK"
  skip "pipeline lineage step: lineage has nodes"
fi

# =============================================================================
# 240. Lineage edge sorting
# =============================================================================
echo ""
echo "=== 240. Lineage edge sorting ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_lineage_sort
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "transform", "input": "z_input.csv", "recipe": "a_recipe.json", "output": "output.csv"}
  ]
}
EOF

  $DPIPE lineage --config "$DIR/pipeline.json" --output "$DIR/lineage.json" 2>/dev/null

  # Edges should be sorted by step then by from
  EDGE0_FROM=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(d['edges'][0]['from'])" 2>/dev/null)
  EDGE1_FROM=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(d['edges'][1]['from'])" 2>/dev/null)
  check "lineage edge sort: first edge from a_recipe.json" "a_recipe.json" "$EDGE0_FROM"
  check "lineage edge sort: second edge from z_input.csv" "z_input.csv" "$EDGE1_FROM"
else
  skip "lineage edge sort: first edge from a_recipe.json"
  skip "lineage edge sort: second edge from z_input.csv"
fi

# =============================================================================
# 241. Lineage node type is always file
# =============================================================================
echo ""
echo "=== 241. Lineage node type ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_lineage_nodetype
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "ingest", "file": "data.csv", "output": "clean.csv"}
  ]
}
EOF

  $DPIPE lineage --config "$DIR/pipeline.json" --output "$DIR/lineage.json" 2>/dev/null

  ALL_FILE_TYPE=$(python3 -c "
import json
d=json.load(open('$DIR/lineage.json'))
print('yes' if all(n['type'] == 'file' for n in d['nodes']) else 'no')
" 2>/dev/null)
  check "lineage node type: all nodes are file type" "yes" "$ALL_FILE_TYPE"
else
  skip "lineage node type: all nodes are file type"
fi

# =============================================================================
# 242. Lineage 2-space indented JSON with trailing newline
# =============================================================================
echo ""
echo "=== 242. Lineage JSON format ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_lineage_format
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "ingest", "file": "data.csv", "output": "clean.csv"}
  ]
}
EOF

  $DPIPE lineage --config "$DIR/pipeline.json" --output "$DIR/lineage.json" 2>/dev/null

  # Check 2-space indentation
  HAS_2SPACE=$(python3 -c "
content = open('$DIR/lineage.json').read()
print('yes' if '  \"nodes\"' in content else 'no')
" 2>/dev/null)
  check "lineage format: 2-space indentation" "yes" "$HAS_2SPACE"

  # Check trailing newline
  TRAILING_NL=$(python3 -c "
content = open('$DIR/lineage.json','rb').read()
print('yes' if content.endswith(b'\n') else 'no')
" 2>/dev/null)
  check "lineage format: trailing newline" "yes" "$TRAILING_NL"
else
  skip "lineage format: 2-space indentation"
  skip "lineage format: trailing newline"
fi

# =============================================================================
# 243. Lineage manifest step (CORRECTED: no inputs, no edges)
# =============================================================================
echo ""
echo "=== 243. Lineage manifest step ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_lineage_manifest
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "manifest", "dir": "output_dir", "output": "manifest.json"}
  ]
}
EOF

  $DPIPE lineage --config "$DIR/pipeline.json" --output "$DIR/lineage.json" 2>/dev/null

  # CORRECTED: manifest step has no inputs (dir is not a file input)
  STEP_INPUTS=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(len(d['steps'][0]['inputs']))" 2>/dev/null)
  check "lineage manifest step: inputs is empty" "0" "$STEP_INPUTS"

  STEP_OUTPUT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(d['steps'][0]['output'])" 2>/dev/null)
  check "lineage manifest step: output is manifest.json" "manifest.json" "$STEP_OUTPUT"

  # CORRECTED: no edges since manifest has no inputs
  EDGE_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(len(d['edges']))" 2>/dev/null)
  check "lineage manifest step: no edges" "0" "$EDGE_COUNT"

  # Only one node (manifest.json), output_dir should NOT be a node
  NODE_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(len(d['nodes']))" 2>/dev/null)
  check "lineage manifest step: only 1 node" "1" "$NODE_COUNT"
else
  skip "lineage manifest step: inputs is empty"
  skip "lineage manifest step: output is manifest.json"
  skip "lineage manifest step: no edges"
  skip "lineage manifest step: only 1 node"
fi


# =============================================================================
# 244. Audit log: basic transform audit
# =============================================================================
echo ""
echo "=== 244. Audit basic ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_audit_basic
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,20
3,30
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "filter", "column": "value", "condition": "gt", "threshold": 15}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 --audit "$DIR/audit.json" 2>/dev/null
  AUDIT_EXIT=$?
  check "audit basic: exit code 0" "0" "$AUDIT_EXIT"

  # Check audit file exists
  if [ -f "$DIR/audit.json" ]; then
    check "audit basic: audit file created" "1" "1"
  else
    check "audit basic: audit file created" "1" "0"
  fi

  # Check audit has one entry
  ENTRY_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print(len(d))" 2>/dev/null)
  check "audit basic: one entry" "1" "$ENTRY_COUNT"

  # Check command field
  CMD=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print(d[0]['command'])" 2>/dev/null)
  check "audit basic: command is transform" "transform" "$CMD"

  # Check success field
  SUCCESS=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print(d[0]['success'])" 2>/dev/null)
  check "audit basic: success is True" "True" "$SUCCESS"

  # Check error is null
  ERR_VAL=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print(d[0]['error'])" 2>/dev/null)
  check "audit basic: error is None" "None" "$ERR_VAL"

  # Check timestamp is present
  HAS_TS=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print('yes' if 'timestamp' in d[0] and len(d[0]['timestamp']) > 0 else 'no')" 2>/dev/null)
  check "audit basic: has timestamp" "yes" "$HAS_TS"

  # Check duration_ms is an integer >= 0
  DUR_OK=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print('yes' if isinstance(d[0]['duration_ms'], int) and d[0]['duration_ms'] >= 0 else 'no')" 2>/dev/null)
  check "audit basic: duration_ms is non-negative int" "yes" "$DUR_OK"
else
  skip "audit basic: exit code 0"
  skip "audit basic: audit file created"
  skip "audit basic: one entry"
  skip "audit basic: command is transform"
  skip "audit basic: success is True"
  skip "audit basic: error is None"
  skip "audit basic: has timestamp"
  skip "audit basic: duration_ms is non-negative int"
fi

# =============================================================================
# 245. Audit log: input and output sizes
# =============================================================================
echo ""
echo "=== 245. Audit sizes ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_audit_sizes
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,20
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "sort", "column": "id", "order": "asc"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 --audit "$DIR/audit.json" 2>/dev/null

  INPUT_SZ=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print(d[0]['input_size'])" 2>/dev/null)
  EXPECTED_SZ=$(wc -c < "$DIR/input.csv" | tr -d ' ')
  check "audit sizes: input_size matches file" "$EXPECTED_SZ" "$INPUT_SZ"

  OUTPUT_SZ=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print(d[0]['output_size'])" 2>/dev/null)
  EXPECTED_OUT=$(wc -c < "$DIR/out.csv" | tr -d ' ')
  check "audit sizes: output_size matches file" "$EXPECTED_OUT" "$OUTPUT_SZ"
else
  skip "audit sizes: input_size matches file"
  skip "audit sizes: output_size matches file"
fi

# =============================================================================
# 246. Audit log: appends to existing file
# =============================================================================
echo ""
echo "=== 246. Audit append ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_audit_append
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
2,20
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "sort", "column": "id", "order": "asc"}]
EOF

  # First command
  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 --audit "$DIR/audit.json" 2>/dev/null
  # Second command
  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out2.csv" --seed 42 --audit "$DIR/audit.json" 2>/dev/null

  ENTRY_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print(len(d))" 2>/dev/null)
  check "audit append: two entries after two commands" "2" "$ENTRY_COUNT"
else
  skip "audit append: two entries after two commands"
fi

# =============================================================================
# 247. Audit log: args exclude --audit flag
# =============================================================================
echo ""
echo "=== 247. Audit args ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_audit_args
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "sort", "column": "id", "order": "asc"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 --audit "$DIR/audit.json" 2>/dev/null

  # Check that --audit is not in args
  HAS_AUDIT_ARG=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print('yes' if '--audit' in d[0]['args'] else 'no')" 2>/dev/null)
  check "audit args: --audit not in args" "no" "$HAS_AUDIT_ARG"

  # Check --input is in args
  HAS_INPUT_ARG=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print('yes' if '--input' in d[0]['args'] else 'no')" 2>/dev/null)
  check "audit args: --input in args" "yes" "$HAS_INPUT_ARG"
else
  skip "audit args: --audit not in args"
  skip "audit args: --input in args"
fi

# =============================================================================
# 248. Audit log: failed command
# =============================================================================
echo ""
echo "=== 248. Audit failure ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_audit_fail
  rm -rf "$DIR"
  mkdir -p "$DIR"

  $DPIPE transform --input /tmp/nonexistent_audit_file.csv --recipe /tmp/nonexistent_recipe.json --output "$DIR/out.csv" --seed 42 --audit "$DIR/audit.json" 2>/dev/null
  AUDIT_EXIT=$?
  check "audit failure: exit code 1" "1" "$AUDIT_EXIT"

  # Audit should still be written
  if [ -f "$DIR/audit.json" ]; then
    SUCCESS=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print(d[0]['success'])" 2>/dev/null)
    check "audit failure: success is False" "False" "$SUCCESS"

    ERR_MSG=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print('yes' if d[0]['error'] is not None and len(d[0]['error']) > 0 else 'no')" 2>/dev/null)
    check "audit failure: error message present" "yes" "$ERR_MSG"

    OUT_SZ=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print(d[0]['output_size'])" 2>/dev/null)
    check "audit failure: output_size is None" "None" "$OUT_SZ"
  else
    check "audit failure: success is False" "1" "0"
    check "audit failure: error message present" "1" "0"
    check "audit failure: output_size is None" "1" "0"
  fi
else
  skip "audit failure: exit code 1"
  skip "audit failure: success is False"
  skip "audit failure: error message present"
  skip "audit failure: output_size is None"
fi

# =============================================================================
# 249. Audit log: manifest command (no input)
# =============================================================================
echo ""
echo "=== 249. Audit manifest ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_audit_manifest
  rm -rf "$DIR"
  mkdir -p "$DIR/data"

  echo "id,val" > "$DIR/data/f.csv"
  echo "1,10" >> "$DIR/data/f.csv"

  $DPIPE manifest --dir "$DIR/data" --output "$DIR/manifest.json" --audit "$DIR/audit.json" 2>/dev/null

  CMD=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print(d[0]['command'])" 2>/dev/null)
  check "audit manifest: command is manifest" "manifest" "$CMD"

  INPUT_SZ=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print(d[0]['input_size'])" 2>/dev/null)
  check "audit manifest: input_size is None" "None" "$INPUT_SZ"
else
  skip "audit manifest: command is manifest"
  skip "audit manifest: input_size is None"
fi

# =============================================================================
# 250. Audit log: 2-space indentation and trailing newline
# =============================================================================
echo ""
echo "=== 250. Audit format ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_audit_format
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,value
1,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "sort", "column": "id", "order": "asc"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 --audit "$DIR/audit.json" 2>/dev/null

  HAS_2SPACE=$(python3 -c "
content = open('$DIR/audit.json').read()
print('yes' if '  {' in content else 'no')
" 2>/dev/null)
  check "audit format: 2-space indentation" "yes" "$HAS_2SPACE"

  TRAILING_NL=$(python3 -c "
content = open('$DIR/audit.json','rb').read()
print('yes' if content.endswith(b'\n') else 'no')
" 2>/dev/null)
  check "audit format: trailing newline" "yes" "$TRAILING_NL"
else
  skip "audit format: 2-space indentation"
  skip "audit format: trailing newline"
fi

# =============================================================================
# 251. Impute mean
# =============================================================================
echo ""
echo "=== 251. Impute mean ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_impute_mean
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,score
1,10
2,
3,20
4,
5,30
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "impute", "column": "score", "method": "mean"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # Mean of 10,20,30 = 20
  ROW2=$(sed -n '3p' "$DIR/out.csv" | cut -d',' -f2)
  check "impute mean: row 2 filled with 20" "20" "$ROW2"

  ROW4=$(sed -n '5p' "$DIR/out.csv" | cut -d',' -f2)
  check "impute mean: row 4 filled with 20" "20" "$ROW4"

  # Non-empty values should be unchanged
  ROW1=$(sed -n '2p' "$DIR/out.csv" | cut -d',' -f2)
  check "impute mean: row 1 unchanged" "10" "$ROW1"
else
  skip "impute mean: row 2 filled with 20"
  skip "impute mean: row 4 filled with 20"
  skip "impute mean: row 1 unchanged"
fi

# =============================================================================
# 252. Impute median
# =============================================================================
echo ""
echo "=== 252. Impute median ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_impute_median
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,score
1,10
2,
3,30
4,20
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "impute", "column": "score", "method": "median"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # Sorted values: 10, 20, 30 -> median = 20 (middle value)
  ROW2=$(sed -n '3p' "$DIR/out.csv" | cut -d',' -f2)
  check "impute median: row 2 filled with 20" "20" "$ROW2"
else
  skip "impute median: row 2 filled with 20"
fi

# =============================================================================
# 253. Impute mode
# =============================================================================
echo ""
echo "=== 253. Impute mode ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_impute_mode
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,score
1,10
2,10
3,
4,20
5,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "impute", "column": "score", "method": "mode"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # Mode of 10,10,20,10 = 10 (most frequent)
  ROW3=$(sed -n '4p' "$DIR/out.csv" | cut -d',' -f2)
  check "impute mode: row 3 filled with 10" "10" "$ROW3"
else
  skip "impute mode: row 3 filled with 10"
fi

# =============================================================================
# 254. Impute mode tie-breaking
# =============================================================================
echo ""
echo "=== 254. Impute mode tie ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_impute_mode_tie
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,score
1,30
2,10
3,
4,30
5,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "impute", "column": "score", "method": "mode"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # Mode tie between 10 (2x) and 30 (2x) -> pick smallest = 10
  ROW3=$(sed -n '4p' "$DIR/out.csv" | cut -d',' -f2)
  check "impute mode tie: row 3 filled with 10" "10" "$ROW3"
else
  skip "impute mode tie: row 3 filled with 10"
fi

# =============================================================================
# 255. Impute column not found
# =============================================================================
echo ""
echo "=== 255. Impute error ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_impute_err
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,score
1,10
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "impute", "column": "nonexistent", "method": "mean"}]
EOF

  ERR_OUT=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>&1)
  ERR_EXIT=$?
  check "impute error: exit code 1" "1" "$ERR_EXIT"
  check_contains "impute error: column not found" "column nonexistent not found" "$ERR_OUT"
else
  skip "impute error: exit code 1"
  skip "impute error: column not found"
fi

# =============================================================================
# 256. Impute with no empty values (no-op)
# =============================================================================
echo ""
echo "=== 256. Impute no-op ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_impute_noop
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,score
1,10
2,20
3,30
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "impute", "column": "score", "method": "mean"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv" | cut -d',' -f2)
  ROW2=$(sed -n '3p' "$DIR/out.csv" | cut -d',' -f2)
  ROW3=$(sed -n '4p' "$DIR/out.csv" | cut -d',' -f2)
  check "impute noop: row 1 unchanged" "10" "$ROW1"
  check "impute noop: row 2 unchanged" "20" "$ROW2"
  check "impute noop: row 3 unchanged" "30" "$ROW3"
else
  skip "impute noop: row 1 unchanged"
  skip "impute noop: row 2 unchanged"
  skip "impute noop: row 3 unchanged"
fi

# =============================================================================
# 257. Audit with verify (no output)
# =============================================================================
echo ""
echo "=== 257. Audit verify ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_audit_verify
  rm -rf "$DIR"
  mkdir -p "$DIR"

  echo "test data for audit verify" > "$DIR/testfile.txt"

  python3 -c "
import hashlib
data = open('$DIR/testfile.txt','rb').read()
h = hashlib.blake2b(data, digest_size=32).hexdigest()
open('$DIR/correct.checksum','w').write(h + '\n')
"

  $DPIPE verify --file "$DIR/testfile.txt" --checksum "$DIR/correct.checksum" --audit "$DIR/audit.json" 2>/dev/null

  CMD=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print(d[0]['command'])" 2>/dev/null)
  check "audit verify: command is verify" "verify" "$CMD"

  OUT_SZ=$(python3 -c "import json; d=json.load(open('$DIR/audit.json')); print(d[0]['output_size'])" 2>/dev/null)
  check "audit verify: output_size is None" "None" "$OUT_SZ"
else
  skip "audit verify: command is verify"
  skip "audit verify: output_size is None"
fi

# =============================================================================
# 258. Impute all empty (no numeric values)
# =============================================================================
echo ""
echo "=== 258. Impute all empty ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_impute_allblank
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,score
1,
2,
3,
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "impute", "column": "score", "method": "mean"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null
  IMP_EXIT=$?
  check "impute all empty: exit code 0" "0" "$IMP_EXIT"

  # All should remain empty since no numeric values to compute from
  ROW1=$(sed -n '2p' "$DIR/out.csv" | cut -d',' -f2)
  check "impute all empty: row 1 still empty" "" "$ROW1"
else
  skip "impute all empty: exit code 0"
  skip "impute all empty: row 1 still empty"
fi



# =============================================================================
# 259. Temporal diff
# =============================================================================
echo ""
echo "=== 259. Temporal diff ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_temporal_diff
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,price
1,100
2,110
3,105
4,120
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "temporal", "column": "price", "function": "diff", "as": "price_diff"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null
  T_EXIT=$?
  check "temporal diff: exit code 0" "0" "$T_EXIT"

  HEADER=$(head -1 "$DIR/out.csv" 2>/dev/null)
  check "temporal diff: header" "id,price,price_diff" "$HEADER"

  # First row: empty (no previous)
  ROW1_DIFF=$(sed -n '2p' "$DIR/out.csv" | cut -d',' -f3)
  check "temporal diff: row 1 empty" "" "$ROW1_DIFF"

  # Second row: 110 - 100 = 10
  ROW2_DIFF=$(sed -n '3p' "$DIR/out.csv" | cut -d',' -f3)
  check "temporal diff: row 2 = 10" "10" "$ROW2_DIFF"

  # Third row: 105 - 110 = -5
  ROW3_DIFF=$(sed -n '4p' "$DIR/out.csv" | cut -d',' -f3)
  check "temporal diff: row 3 = -5" "-5" "$ROW3_DIFF"

  # Fourth row: 120 - 105 = 15
  ROW4_DIFF=$(sed -n '5p' "$DIR/out.csv" | cut -d',' -f3)
  check "temporal diff: row 4 = 15" "15" "$ROW4_DIFF"
else
  skip "temporal diff: exit code 0"
  skip "temporal diff: header"
  skip "temporal diff: row 1 empty"
  skip "temporal diff: row 2 = 10"
  skip "temporal diff: row 3 = -5"
  skip "temporal diff: row 4 = 15"
fi

# =============================================================================
# 260. Temporal cumsum
# =============================================================================
echo ""
echo "=== 260. Temporal cumsum ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_temporal_cumsum
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,amount
1,10
2,20
3,30
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "temporal", "column": "amount", "function": "cumsum", "as": "running_total"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv" | rev | cut -d',' -f1 | rev)
  check "temporal cumsum: row 1 = 10" "10" "$ROW1"

  ROW2=$(sed -n '3p' "$DIR/out.csv" | rev | cut -d',' -f1 | rev)
  check "temporal cumsum: row 2 = 30" "30" "$ROW2"

  ROW3=$(sed -n '4p' "$DIR/out.csv" | rev | cut -d',' -f1 | rev)
  check "temporal cumsum: row 3 = 60" "60" "$ROW3"
else
  skip "temporal cumsum: row 1 = 10"
  skip "temporal cumsum: row 2 = 30"
  skip "temporal cumsum: row 3 = 60"
fi

# =============================================================================
# 261. Temporal pct_change
# =============================================================================
echo ""
echo "=== 261. Temporal pct_change ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_temporal_pctchange
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,price
1,100
2,150
3,120
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "temporal", "column": "price", "function": "pct_change", "as": "pct"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # First row: empty
  ROW1=$(sed -n '2p' "$DIR/out.csv" | rev | cut -d',' -f1 | rev)
  check "temporal pct_change: row 1 empty" "" "$ROW1"

  # Second row: (150-100)/100 = 0.5
  ROW2=$(sed -n '3p' "$DIR/out.csv" | rev | cut -d',' -f1 | rev)
  check "temporal pct_change: row 2 = 0.5" "0.5" "$ROW2"

  # Third row: (120-150)/150 = -0.2
  ROW3=$(sed -n '4p' "$DIR/out.csv" | rev | cut -d',' -f1 | rev)
  check "temporal pct_change: row 3 = -0.2" "-0.2" "$ROW3"
else
  skip "temporal pct_change: row 1 empty"
  skip "temporal pct_change: row 2 = 0.5"
  skip "temporal pct_change: row 3 = -0.2"
fi

# =============================================================================
# 262. Temporal pct_change with zero previous
# =============================================================================
echo ""
echo "=== 262. Temporal pct_change zero ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_temporal_pctzero
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,price
1,0
2,100
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "temporal", "column": "price", "function": "pct_change", "as": "pct"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # Second row: previous is 0, so empty
  ROW2=$(sed -n '3p' "$DIR/out.csv" | rev | cut -d',' -f1 | rev)
  check "temporal pct_change zero: row 2 empty" "" "$ROW2"
else
  skip "temporal pct_change zero: row 2 empty"
fi

# =============================================================================
# 263. Temporal diff with empty cell
# =============================================================================
echo ""
echo "=== 263. Temporal diff empty ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_temporal_diff_empty
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,price
1,100
2,
3,120
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "temporal", "column": "price", "function": "diff", "as": "d"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  # Row 2: empty source -> empty output
  ROW2=$(sed -n '3p' "$DIR/out.csv" | rev | cut -d',' -f1 | rev)
  check "temporal diff empty: row 2 empty" "" "$ROW2"

  # Row 3: after empty cell, diff is also empty (reset)
  ROW3=$(sed -n '4p' "$DIR/out.csv" | rev | cut -d',' -f1 | rev)
  check "temporal diff empty: row 3 empty (reset)" "" "$ROW3"
else
  skip "temporal diff empty: row 2 empty"
  skip "temporal diff empty: row 3 empty (reset)"
fi

# =============================================================================
# 264. Temporal cumsum with empty cell
# =============================================================================
echo ""
echo "=== 264. Temporal cumsum empty ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_temporal_cumsum_empty
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,amount
1,10
2,
3,20
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "temporal", "column": "amount", "function": "cumsum", "as": "cs"}]
EOF

  $DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>/dev/null

  ROW1=$(sed -n '2p' "$DIR/out.csv" | rev | cut -d',' -f1 | rev)
  check "temporal cumsum empty: row 1 = 10" "10" "$ROW1"

  # Row 2: empty source -> empty output, but cumsum doesn't reset
  ROW2=$(sed -n '3p' "$DIR/out.csv" | rev | cut -d',' -f1 | rev)
  check "temporal cumsum empty: row 2 empty" "" "$ROW2"

  # Row 3: cumsum continues from 10 + 20 = 30
  ROW3=$(sed -n '4p' "$DIR/out.csv" | rev | cut -d',' -f1 | rev)
  check "temporal cumsum empty: row 3 = 30" "30" "$ROW3"
else
  skip "temporal cumsum empty: row 1 = 10"
  skip "temporal cumsum empty: row 2 empty"
  skip "temporal cumsum empty: row 3 = 30"
fi

# =============================================================================
# 265. Temporal column not found
# =============================================================================
echo ""
echo "=== 265. Temporal error ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_temporal_err
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/input.csv" << 'EOF'
id,price
1,100
EOF

  cat > "$DIR/recipe.json" << 'EOF'
[{"op": "temporal", "column": "nonexistent", "function": "diff", "as": "d"}]
EOF

  ERR_OUT=$($DPIPE transform --input "$DIR/input.csv" --recipe "$DIR/recipe.json" --output "$DIR/out.csv" --seed 42 2>&1)
  ERR_EXIT=$?
  check "temporal error: exit code 1" "1" "$ERR_EXIT"
  check_contains "temporal error: column not found" "column nonexistent not found" "$ERR_OUT"
else
  skip "temporal error: exit code 1"
  skip "temporal error: column not found"
fi

# =============================================================================
# 266. Lineage manifest corrected: mixed pipeline
# =============================================================================
echo ""
echo "=== 266. Lineage manifest corrected ==="
if [ "$BUILD_OK" = "1" ]; then
  DIR=/tmp/test_lineage_manifest_corrected
  rm -rf "$DIR"
  mkdir -p "$DIR"

  cat > "$DIR/pipeline.json" << 'EOF'
{
  "seed": 42,
  "steps": [
    {"type": "ingest", "file": "raw.csv", "output": "clean.csv"},
    {"type": "manifest", "dir": "output_dir", "output": "manifest.json"},
    {"type": "verify", "file": "manifest.json", "checksum": "manifest.json.blake2b"}
  ]
}
EOF

  $DPIPE lineage --config "$DIR/pipeline.json" --output "$DIR/lineage.json" 2>/dev/null

  # Nodes should be: clean.csv, manifest.json, manifest.json.blake2b, raw.csv (4 total, NOT output_dir)
  NODE_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(len(d['nodes']))" 2>/dev/null)
  check "lineage manifest corrected: 4 nodes" "4" "$NODE_COUNT"

  # Check output_dir is NOT a node
  HAS_OUTPUT_DIR=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); ids=[n['id'] for n in d['nodes']]; print('yes' if 'output_dir' in ids else 'no')" 2>/dev/null)
  check "lineage manifest corrected: no output_dir node" "no" "$HAS_OUTPUT_DIR"

  # Edges should only be from ingest (raw.csv -> clean.csv), none from manifest
  EDGE_COUNT=$(python3 -c "import json; d=json.load(open('$DIR/lineage.json')); print(len(d['edges']))" 2>/dev/null)
  check "lineage manifest corrected: 1 edge" "1" "$EDGE_COUNT"
else
  skip "lineage manifest corrected: 4 nodes"
  skip "lineage manifest corrected: no output_dir node"
  skip "lineage manifest corrected: 1 edge"
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
