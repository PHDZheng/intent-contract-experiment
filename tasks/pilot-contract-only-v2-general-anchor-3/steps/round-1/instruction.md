[INTENT CONTRACT V2 TRANSITION]

Compiled through round: 1
Normative clause coverage: 39/39
All rendered requirements are MUST requirements.
Transition slice: 48 touched + 0 explicit dependencies + 0 execution anchors.
Provenance and complete state are retained in the compiler audit artifacts, not repeated here.

[CURRENT TRANSITION SPECIFICATION]

## `tool.identity_and_role`
{"algorithm":["Read structured CSV data, apply configured transformation chains, and write results to output files."],"interface":[{"key":"executable","value":"dpipe"},{"key":"implementation_language","value":"Go"},{"key":"program_type","value":"CLI"}],"invariants":["The tool operates as a command-line data pipeline."],"summary":"Provide a Go CLI named dpipe for deterministic structured-data pipelines."}

## `ingest.cli_interface`
{"interface":[{"key":"syntax","value":"dpipe ingest --input <path> --schema <path> --output <path>"},{"key":"--input","value":"CSV input path"},{"key":"--schema","value":"JSON schema path"},{"key":"--output","value":"valid-output CSV path"}],"summary":"Expose the ingest command with required input, schema, and output paths."}

## `ingest.csv_and_schema_model`
{"algorithm":["Read the CSV at --input.","Treat its first row as the header.","For every data row, validate values using the corresponding schema column declarations."],"input_schema":[{"key":"CSV","value":"CSV file whose first row is the header."},{"key":"schema.columns","value":"Array of column objects; fields shown are name, type, required, unique, min, max, and pattern as applicable."},{"key":"schema.primary_key","value":"Array of key-column names."},{"key":"supported_types","value":"int, float, string, datetime"},{"key":"datetime_format","value":"RFC 3339"},{"key":"normative_schema_example","value":"{\"columns\":[{\"name\":\"id\",\"type\":\"int\",\"required\":true,\"unique\":true},{\"name\":\"value\",\"type\":\"float\",\"required\":true,\"min\":0,\"max\":1000},{\"name\":\"label\",\"type\":\"string\",\"required\":false,\"pattern\":\"^[A-Z]\"},{\"name\":\"timestamp\",\"type\":\"datetime\",\"required\":true}],\"primary_key\":[\"id\"]}"}],"integration":[{"key":"schema_source","value":"File supplied by --schema"}],"invariants":["Only int, float, string, and RFC 3339 datetime are supported schema types."],"summary":"Read headered CSV and validate rows against the declared JSON schema model and supported types."}

## `ingest.column_constraints`
{"algorithm":["For min/max, reject values outside [min,max].","For pattern, reject values that do not match the Go regular expression.","For unique, keep the first otherwise-valid occurrence in input order and reject later duplicates."],"edge_cases":["All three constraint kinds are optional."],"formulas":[{"key":"range_predicate","value":"min <= value <= max, with either optional bound applied when present"}],"input_schema":[{"key":"unique","value":"Optional boolean; values among otherwise-valid rows must be unique per column."},{"key":"min,max","value":"Optional numbers valid only for int and float columns; bounds are inclusive."},{"key":"pattern","value":"Optional string valid only for string columns; interpreted as a Go regular expression."}],"ordering":["Duplicate detection follows input file order and occurs after all other validations pass."],"output_schema":[{"key":"unique_rejection_reason","value":"duplicate value for unique column: <name>"},{"key":"range_rejection_reason","value":"value out of range for column <name>: <value>"},{"key":"pattern_rejection_reason","value":"value does not match pattern for column <name>: <value>"}],"summary":"Enforce optional unique, numeric range, and string-pattern constraints with exact rejection reasons."}

## `ingest.validation_order`
{"algorithm":["For each row perform required/type checks.","Then perform range checks.","Then perform pattern checks.","After steps 1-3 have been applied to all rows, check uniqueness across rows still valid.","During uniqueness checking retain the first occurrence and reject subsequent duplicates."],"ordering":["Required/type checks precede range checks; range checks precede pattern checks; uniqueness follows those checks and uses input file order."],"summary":"Apply ingest validation stages in the prescribed order."}

## `ingest.primary_key_shape`
{"edge_cases":["The array may not be empty."],"input_schema":[{"key":"primary_key","value":"Array of one or more column-name strings; multiple names form a composite key."}],"ordering":["Primary-key declaration order is significant."],"summary":"Require primary_key to support one or more key columns."}

## `ingest.valid_and_rejected_outputs`
{"algorithm":["Route each valid row to <output>.","Route each invalid row to <output>.rejected with its rejection reason."],"formatting":[{"key":"valid_format","value":"CSV"},{"key":"rejected_format","value":"Same CSV columns plus appended rejection_reason column"}],"output_schema":[{"key":"<output>","value":"CSV containing valid rows."},{"key":"<output>.rejected","value":"CSV in the input CSV format with rejection_reason appended as the final column."},{"key":"rejection_reason","value":"Reason the row failed validation."}],"summary":"Write valid and rejected ingest rows to separate CSV files."}

## `ingest.output_ordering`
{"algorithm":["Compare primary-key columns left to right in declaration order.","Sort every key component ascending using its declared type."],"ordering":["Primary-key column 1 is primary, column 2 breaks ties, and so on.","int and float use numeric ordering; string uses lexicographic ordering; datetime uses chronological ordering; all are ascending."],"summary":"Sort valid ingest output by the typed composite primary key."}

## `ingest.output_checksum`
{"algorithm":["Compute SHA-256 over the exact raw bytes of <output>.","Hex-encode the digest and append a newline in <output>.sha256."],"formatting":[{"key":"checksum_file","value":"Single hex string followed by newline"}],"formulas":[{"key":"digest","value":"SHA-256(raw_bytes(<output>))"}],"input_schema":[{"key":"hash_input","value":"Raw bytes of <output>."}],"output_schema":[{"key":"<output>.sha256","value":"One lowercase-or-uppercase-compatible hexadecimal SHA-256 string followed by one newline."}],"preconditions":["The output CSV has been fully serialized."],"summary":"Write a SHA-256 sidecar for the valid ingest output."}

## `transform.cli_interface`
{"interface":[{"key":"syntax","value":"dpipe transform --input <path> --recipe <path> --output <path> --seed <uint64>"},{"key":"--input","value":"Headered CSV input path"},{"key":"--recipe","value":"JSON recipe path"},{"key":"--output","value":"Result CSV path"},{"key":"--seed","value":"Unsigned 64-bit deterministic seed"}],"summary":"Expose the transform command with input, recipe, output, and uint64 seed arguments."}

## `transform.recipe_execution`
{"algorithm":["Read the headered input CSV.","Read the recipe as an array.","Apply each transformation object to the current dataset in array order, passing each result to the next transformation."],"edge_cases":["Previously ingested CSV is typical but not required."],"input_schema":[{"key":"input","value":"Any CSV with a header row; it need not have been produced by ingest."},{"key":"recipe","value":"JSON array of transformation objects, each selected by its op field."},{"key":"normative_recipe_shape","value":"Objects may use op-specific fields demonstrated for filter, derive, sample, sort, rename, drop, aggregate, join, window, pivot, unpivot, and fill."}],"integration":[{"key":"chain","value":"Each operation consumes the immediately preceding dataset."}],"notes":["Normative recipe examples include: filter value gt 10.0; derive score as value * 2 + 1; sample 0.5; stable descending sort by score; rename label to category; drop timestamp; grouped aggregations; left join other.csv on id; rank window; pivot; unpivot; and forward fill."],"ordering":["Recipe array order is execution order."],"summary":"Accept any headered CSV and execute recipe transformation objects sequentially."}

## `transform.filter`
{"algorithm":["Evaluate column condition threshold for each row.","Keep exactly the rows for which the condition is true."],"formulas":[{"key":"conditions","value":"gt: x>t; gte: x>=t; lt: x<t; lte: x<=t; eq: x=t; neq: x!=t"}],"input_schema":[{"key":"op","value":"filter"},{"key":"column","value":"Column to compare"},{"key":"condition","value":"One of gt, gte, lt, lte, eq, neq"},{"key":"threshold","value":"Comparison threshold"}],"ordering":["Preserve the relative order of retained rows."],"summary":"Filter rows by comparing a named column to a threshold."}

## `transform.derive_operation`
{"algorithm":["Evaluate expression for every row.","Add the result under name."],"input_schema":[{"key":"op","value":"derive"},{"key":"name","value":"Name of the new column"},{"key":"expression","value":"Numeric expression over existing columns"}],"output_schema":[{"key":"derived_column","value":"New column named by name containing the evaluated expression result."}],"preconditions":["Referenced expression columns are numeric existing columns."],"summary":"Derive a new column from an expression over existing numeric columns."}

## `derive.expression_grammar_and_precedence`
{"algorithm":["Parse operators by precedence from lowest to highest: ||; &&; == and !=; >, >=, <, <=; + and -; *, /, %; unary -; then calls, parentheses, references, and literals.","Logical OR returns 1 when either operand is >0, else 0.","Logical AND returns 1 when both operands are >0, else 0.","Equality and relational operators perform numeric comparison and return 1 or 0."],"formulas":[{"key":"inline_condition_example","value":"(value > 10 && value < 100) * value returns value when value is in range and 0 otherwise."}],"input_schema":[{"key":"atoms","value":"Function calls, parenthesized expressions, column references, and numeric literals."}],"invariants":["Comparison results are numeric 1 or 0."],"ordering":["The listed precedence is lowest to highest."],"summary":"Evaluate derive expressions with the prescribed operators, truth semantics, and precedence."}

## `derive.nan_arithmetic`
{"algorithm":["Return NaN for division by zero.","Return NaN for modulo by zero.","Return 0 for every comparison having NaN on either side."],"edge_cases":["NaN on either comparison operand yields 0."],"formulas":[{"key":"x/0","value":"NaN"},{"key":"x%0","value":"NaN"},{"key":"comparison_with_NaN","value":"0"}],"summary":"Use NaN for division/modulo by zero and make NaN comparisons false."}

## `derive.functions`
{"algorithm":["abs(x): absolute value.","sqrt(x): square root, or NaN for negative x.","ceil(x): smallest integer >= x.","floor(x): largest integer <= x.","round(x,n): round x to non-negative integer n decimal places; half-values away from zero.","pow(x,y): x raised to y.","log(x): natural logarithm, or NaN for non-positive x.","min(x,y) and max(x,y): minimum and maximum.","if(cond,x,y): x when cond>0, otherwise y.","clamp(x,lo,hi): lo when x<lo, hi when x>hi, otherwise x.","coalesce(x,y): x unless x is NaN, otherwise y.","Allow calls to nest recursively."],"edge_cases":["sqrt of a negative input and log of a non-positive input return NaN.","round requires n to be a non-negative integer."],"formulas":[{"key":"nesting_example","value":"round(sqrt(abs(value)), 2)"}],"input_schema":[{"key":"call_syntax","value":"name(arg1, arg2, ...)"}],"summary":"Support nested, parenthesized, comma-separated derive function calls with exact semantics."}

## `derive.result_formatting`
{"formatting":[{"key":"finite_number","value":"Shortest decimal representation preserving the computed value, with no unnecessary trailing zeros or trailing decimal point."},{"key":"NaN","value":"Literal string NaN"},{"key":"examples","value":"11, not 11.0; 2.5, not 2.50"}],"summary":"Serialize derive results canonically."}

## `transform.sample`
{"algorithm":["Initialize Go's math/rand deterministic PRNG with the given seed.","In input row order generate one random float per row.","Keep the row exactly when the generated float is less than fraction."],"formulas":[{"key":"keep","value":"PRNG.Float() < fraction"}],"input_schema":[{"key":"op","value":"sample"},{"key":"fraction","value":"Retention fraction"},{"key":"seed","value":"Value supplied by --seed"}],"invariants":["Identical rows, order, fraction, and seed produce identical selection."],"ordering":["Consume random values in input row order; retained rows remain in input order."],"summary":"Sample rows deterministically using Go math/rand initialized from --seed."}

## `transform.sort`
{"algorithm":["Sort by column in the requested direction using a stable sort."],"input_schema":[{"key":"op","value":"sort"},{"key":"column","value":"Sort column"},{"key":"order","value":"asc or desc"}],"ordering":["Break equal-key ties by original row order."],"summary":"Stably sort rows by one column ascending or descending."}

## `transform.rename`
{"algorithm":["Replace the column name from with to."],"input_schema":[{"key":"op","value":"rename"},{"key":"from","value":"Existing column name"},{"key":"to","value":"Replacement column name"}],"ordering":["Do not otherwise reorder rows or columns."],"summary":"Rename a column."}

## `transform.drop`
{"algorithm":["Remove every listed column from the current dataset."],"input_schema":[{"key":"op","value":"drop"},{"key":"columns","value":"Array of column names to remove"}],"ordering":["Preserve relative order of remaining columns and all rows."],"summary":"Remove listed columns."}

## `transform.aggregate_computation`
{"algorithm":["Partition rows by equal group_by values.","sum: sum numeric values, skipping empty/non-numeric; return 0 when none exist.","avg: arithmetic mean of numeric values, skipping empty/non-numeric; return NaN when none exist.","count: count non-empty values in the specified column.","min/max: extrema of numeric values, skipping empty/non-numeric; return NaN when none exist."],"edge_cases":["sum of no numeric values is 0.","avg, min, and max of no numeric values are NaN."],"formulas":[{"key":"avg","value":"sum(numeric values)/count(numeric values)"}],"input_schema":[{"key":"op","value":"aggregate"},{"key":"group_by","value":"Grouping-column array"},{"key":"aggregations","value":"Ordered array of objects with column, function, and as"},{"key":"functions","value":"sum, avg, count, min, max"}],"summary":"Group rows and compute sum, avg, count, min, and max with prescribed empty and non-numeric handling."}

## `aggregate.output_layout_order_and_format`
{"algorithm":["Sort grouped output by group_by values, comparing columns left to right.","Format numeric aggregate results without unnecessary trailing zeros."],"formatting":[{"key":"numeric_results","value":"No unnecessary trailing zeros; for example 10 not 10.0 and 2.5 not 2.50."}],"ordering":["Rows use ascending lexicographic ordering over group_by columns left to right."],"output_schema":[{"key":"columns","value":"group_by columns in declaration order, then aggregation result columns in aggregation declaration order using each as name."}],"summary":"Emit aggregate columns, rows, and numeric strings in deterministic declaration and lexicographic order."}

## `aggregate.having`
{"algorithm":["Parse the referenced aggregated result string as a float.","Compare it numerically with threshold using the filter condition semantics.","Exclude groups that do not satisfy the condition."],"defaults":[{"key":"having","value":"Optional; when omitted, retain all aggregate groups."}],"input_schema":[{"key":"having.column","value":"Must equal an as name declared by an aggregation."},{"key":"having.condition","value":"gt, gte, lt, lte, eq, or neq"},{"key":"having.threshold","value":"Numeric threshold"},{"key":"normative_example","value":"{\"op\":\"aggregate\",\"group_by\":[\"label\"],\"aggregations\":[{\"column\":\"value\",\"function\":\"sum\",\"as\":\"total\"}],\"having\":{\"column\":\"total\",\"condition\":\"gt\",\"threshold\":100}}"}],"ordering":["Apply having after aggregate sorting; removal must not change the relative order of retained rows."],"preconditions":["Aggregation results have been computed, formatted, and sorted."],"summary":"Optionally filter already-formatted aggregate rows by a numeric condition without changing their order."}

## `transform.join`
{"algorithm":["Index right rows by join-key value, retaining only the first row for each value in right file order.","For inner, emit left rows whose key exists on the right.","For left, emit every left row and fill right fields with empty strings when unmatched."],"edge_cases":["Duplicate right keys do not multiply output rows."],"errors":[{"condition":"Join key absent from either dataset.","exit_code":1,"stderr":"ERROR: invalid recipe: join key <name> not found in <left|right> dataset","stdout":null}],"input_schema":[{"key":"op","value":"join"},{"key":"right","value":"Path to right CSV"},{"key":"on","value":"Column name present in both datasets"},{"key":"type","value":"inner or left"}],"ordering":["Preserve current left-dataset row order.","Use the first matching right row by right file order."],"output_schema":[{"key":"columns","value":"All left columns, followed by all right columns except the join key."},{"key":"unmatched_left_join_values","value":"Empty strings for every right-side output column."}],"summary":"Perform deterministic inner or left joins against a headered right CSV."}

## `transform.window_partition_and_order`
{"algorithm":["Partition by the complete partition_by tuple.","Within each partition, sort using order_by from first specification to last.","Break ties across every order_by column by input row order."],"defaults":[{"key":"partition_by","value":"If omitted or empty, place every row in one partition."}],"edge_cases":["An empty partition_by array means one global partition."],"input_schema":[{"key":"op","value":"window"},{"key":"partition_by","value":"Optional array of partition columns."},{"key":"order_by","value":"Array of {column:string, order:asc|desc}; earlier entries have higher priority."},{"key":"as","value":"Name of appended result column."}],"ordering":["Within-partition ordering follows order_by priority and stable input-order ties."],"summary":"Define window partitions, stable within-partition ordering, and output-column naming."}

## `window.functions`
{"algorithm":["rank: assign 1-based rank; equal complete order_by tuples share rank and the following rank advances by tie-group size.","dense_rank: same equality rule but the following distinct rank advances by one.","row_number: assign unique sequential values from 1, with input order breaking ties.","lag/lead: return source_column value offset rows before/after in partition order, or default when that position does not exist.","running_sum: cumulative source_column sum through current row; treat non-numeric values as 0.","running_avg: cumulative mean through current row; skip non-numeric values from numerator and denominator and return NaN when no numeric value has appeared.","ntile: assign groups 1..n; for partition size k, first k mod n groups have ceil(k/n) rows and remaining groups have floor(k/n) rows."],"edge_cases":["running_avg before any numeric value is NaN.","lag/lead outside the partition uses default."],"formulas":[{"key":"rank_tie_example","value":"Two rows tied at rank 1 cause the next rank to be 3."},{"key":"dense_rank_tie_example","value":"Two rows tied at rank 1 cause the next dense rank to be 2."},{"key":"ntile_sizes","value":"First k mod n groups: ceil(k/n); remaining groups: floor(k/n)."}],"input_schema":[{"key":"function","value":"rank, dense_rank, row_number, lag, lead, running_sum, running_avg, or ntile"},{"key":"lag/lead fields","value":"source_column string, offset positive integer, default string"},{"key":"running fields","value":"source_column string"},{"key":"ntile field","value":"n positive integer"}],"notes":["Normative examples specify lag(value, offset 1, default \"0\") partitioned by cat and ordered by id asc; running_sum(value) under the same partition/order; and ntile n=4 over one partition ordered by id asc."],"ordering":["All positional functions use partition order."],"preconditions":["Rows have partition and window order positions."],"summary":"Support rank, dense_rank, row_number, lag, lead, running_sum, running_avg, and ntile with exact semantics."}

## `window.output_layout_and_row_order`
{"algorithm":["Compute window values in partition order.","Attach each value to its originating row.","Emit rows in original input order."],"ordering":["Output row order is original input order, not partition order."],"output_schema":[{"key":"columns","value":"All original columns in original order, followed by the column named by as."}],"summary":"Append the window result while preserving original columns and input row order."}

## `window.result_formatting`
{"formatting":[{"key":"rank,dense_rank,row_number,ntile","value":"Integer string with no decimal point."},{"key":"running_sum,running_avg,lag,lead","value":"Representation without unnecessary trailing zeros."}],"summary":"Format window results according to function family."}

## `transform.referenced_column_error`
{"algorithm":["Validate referenced columns before executing window, pivot, unpivot, or fill.","On the first applicable absent reference, fail rather than producing transformed output."],"errors":[{"condition":"A referenced window partition_by, order_by, or source_column; pivot index, column, or value; unpivot index or columns; or fill columns entry does not exist.","exit_code":1,"stderr":"ERROR: invalid recipe: column <name> not found","stdout":null}],"summary":"Fail transformation operations that reference absent columns with the exact generic column error."}

## `transform.pivot`
{"algorithm":["Create one output row for each unique index-value combination.","Create one pivot column for each unique value in column.","For each index/pivot pair use value from the first matching input row by input order.","Fill missing pairs with empty string."],"edge_cases":["Missing combinations produce empty strings."],"input_schema":[{"key":"op","value":"pivot"},{"key":"index","value":"Array of row-key column names."},{"key":"column","value":"Column whose unique values become headers."},{"key":"value","value":"Column supplying cell values."}],"ordering":["Pivot columns sort ascending lexicographically.","Output rows sort ascending lexicographically by index columns, comparing left to right.","First matching input row wins for duplicate cells."],"output_schema":[{"key":"columns","value":"index columns in declaration order, then unique pivot headers in ascending lexicographic order."},{"key":"missing_cell","value":"Empty string."}],"summary":"Pivot long data to wide data deterministically."}

## `transform.unpivot`
{"algorithm":["For each input row, emit one output row for every columns entry.","Copy index values, put the source column name in name_to, and its value in value_to.","Preserve empty values instead of skipping them."],"edge_cases":["Empty source values still produce rows."],"input_schema":[{"key":"op","value":"unpivot"},{"key":"index","value":"Columns retained as row identifiers."},{"key":"columns","value":"Columns melted into rows."},{"key":"name_to","value":"Output column containing each melted source column name."},{"key":"value_to","value":"Output column containing each melted value."}],"ordering":["Process input rows in original order and melted columns in declaration order."],"output_schema":[{"key":"columns","value":"index columns in declaration order, then name_to, then value_to."}],"summary":"Unpivot wide data to long data while preserving declared and input order."}

## `transform.fill`
{"algorithm":["forward: independently scan each specified column top-to-bottom and replace empties with the most recent non-empty value above.","backward: independently scan each specified column bottom-to-top and replace empties with the nearest non-empty value below.","constant: replace every eligible empty value with value.","Never modify non-empty values."],"edge_cases":["Forward-fill leading empties remain empty.","Backward-fill trailing empties remain empty."],"input_schema":[{"key":"op","value":"fill"},{"key":"columns","value":"Columns whose empty values are eligible."},{"key":"strategy","value":"forward, backward, or constant"},{"key":"value","value":"Replacement string, required only for constant."}],"ordering":["Preserve original row order and all columns."],"summary":"Fill empty cells by forward, backward, or constant strategy without changing non-empty cells or layout."}

## `transform.output_and_checksum`
{"algorithm":["Serialize the current dataset as CSV to <output>.","Compute SHA-256 over its raw bytes.","Write the checksum to <output>.sha256."],"formulas":[{"key":"digest","value":"SHA-256(raw_bytes(<output>))"}],"input_schema":[{"key":"hash_input","value":"Raw bytes of the completed result CSV."}],"output_schema":[{"key":"<output>","value":"Final transformed CSV."},{"key":"<output>.sha256","value":"SHA-256 checksum of <output>."}],"preconditions":["All recipe operations completed successfully."],"summary":"After the final transformation, write the result CSV and its SHA-256 sidecar."}

## `verify.cli_interface`
{"interface":[{"key":"syntax","value":"dpipe verify --file <path> --checksum <path>"},{"key":"--file","value":"File to hash"},{"key":"--checksum","value":"File containing expected hex digest"}],"summary":"Expose the checksum verification command."}

## `verify.checksum_behavior`
{"algorithm":["Read <path> and compute SHA-256.","Read expected hex string from <checksum>.","Compare expected and actual digests."],"errors":[{"condition":"Expected and actual match.","exit_code":0,"stderr":null,"stdout":"VERIFIED"},{"condition":"Expected and actual differ.","exit_code":1,"stderr":null,"stdout":"MISMATCH expected=<expected> actual=<actual>"}],"formulas":[{"key":"actual","value":"hex(SHA-256(raw_bytes(<path>)))"}],"input_schema":[{"key":"file","value":"Raw file bytes."},{"key":"checksum","value":"Expected SHA-256 hexadecimal string read from <checksum>."}],"summary":"Compare a file's SHA-256 with an expected hexadecimal checksum and report exact success or mismatch output."}

## `manifest.cli_interface`
{"interface":[{"key":"syntax","value":"dpipe manifest --dir <path> --output <path>"},{"key":"--dir","value":"Directory tree to scan"},{"key":"--output","value":"JSON manifest path"}],"summary":"Expose the manifest command with directory and output paths."}

## `manifest.generation`
{"algorithm":["Recursively scan <dir> for .csv files.","For each, compute SHA-256, row count, byte size, and relative path.","Sort file entries by path.","Record actual current UTC generation time and write JSON to <output>."],"formatting":[{"key":"generated_at","value":"RFC 3339 UTC"}],"formulas":[{"key":"sha256","value":"hex(SHA-256(raw file bytes))"},{"key":"size_bytes","value":"length(raw file bytes)"}],"input_schema":[{"key":"scan_filter","value":"All files under <dir> whose names end in .csv."}],"invariants":["generated_at is not a fixed deterministic timestamp."],"ordering":["files array is ascending lexicographic by path."],"output_schema":[{"key":"generated_at","value":"RFC 3339 UTC timestamp reflecting actual generation time."},{"key":"files","value":"Array of objects with path, sha256, rows, and size_bytes."},{"key":"files[].path","value":"Path relative to <dir>."},{"key":"files[].sha256","value":"SHA-256 of file raw bytes."},{"key":"files[].rows","value":"CSV row count."},{"key":"files[].size_bytes","value":"File size in bytes."},{"key":"normative_shape","value":"{\"generated_at\":\"<RFC 3339 UTC timestamp>\",\"files\":[{\"path\":\"relative/to/dir/file.csv\",\"sha256\":\"abcdef...\",\"rows\":42,\"size_bytes\":1234}]}"}],"summary":"Recursively inventory CSV files into a path-sorted JSON manifest with live UTC generation time."}

## `pipeline.cli_interface`
{"interface":[{"key":"syntax","value":"dpipe pipeline --config <path>"},{"key":"--config","value":"Pipeline JSON path"}],"summary":"Expose the pipeline command with a JSON configuration path."}

## `pipeline.config_schema`
{"algorithm":["Parse the config as JSON and obtain seed and steps."],"input_schema":[{"key":"seed","value":"Pipeline seed, exemplified by 12345."},{"key":"steps","value":"Ordered array of command-step objects."},{"key":"ingest_step","value":"{\"type\":\"ingest\",\"input\":\"raw.csv\",\"schema\":\"schema.json\",\"output\":\"clean.csv\"}"},{"key":"transform_step","value":"{\"type\":\"transform\",\"input\":\"clean.csv\",\"recipe\":\"recipe.json\",\"output\":\"final.csv\"}"},{"key":"verify_step","value":"{\"type\":\"verify\",\"file\":\"final.csv\",\"checksum\":\"final.csv.sha256\"}"},{"key":"manifest_step","value":"{\"type\":\"manifest\",\"dir\":\".\",\"output\":\"manifest.json\"}"}],"integration":[{"key":"transform_seed","value":"Pipeline seed supplies deterministic transform sampling."}],"ordering":["steps array order is pipeline execution order."],"summary":"Read a pipeline JSON containing a seed and ordered ingest, transform, verify, or manifest steps."}

## `pipeline.execution_and_status`
{"algorithm":["Execute each steps entry sequentially.","Number steps from 1.","If a step fails, stop immediately and exit 1.","If all N steps succeed, exit 0."],"errors":[{"condition":"Step N fails.","exit_code":1,"stderr":null,"stdout":"PIPELINE FAILED at step N: <error>"},{"condition":"All N steps succeed.","exit_code":0,"stderr":null,"stdout":"PIPELINE OK: N steps completed"}],"integration":[{"key":"step_dispatch","value":"Run each step according to its type using the corresponding dpipe behavior."}],"invariants":["N in failure output is 1-indexed."],"ordering":["No later step executes after a failed step."],"summary":"Execute pipeline steps sequentially, stopping at the first failure and reporting exact terminal status."}

## `global.determinism_contract`
{"algorithm":["Avoid nondeterministic traversal, map iteration, ordering, formatting, hashing, and PRNG behavior in every command.","Use the specified deterministic ordering and seed rules."],"edge_cases":["manifest generated_at must reflect wall-clock time and is the sole stated exception."],"integration":[{"key":"scope","value":"ingest, transform, verify, manifest, pipeline, and every pipeline step"}],"invariants":["Except for generated_at, corresponding output files are byte-identical across repeated runs with the same command, inputs, configuration, and seed."],"preconditions":["Command, inputs, configuration, and seed are identical between runs."],"summary":"Produce byte-identical output files for repeated equivalent executions, except for manifest generated_at."}

## `error.missing_input_file`
{"algorithm":["Detect a missing required input path and terminate."],"errors":[{"condition":"A required input file does not exist.","exit_code":1,"stderr":"ERROR: file not found: <path>","stdout":null}],"summary":"Report missing input files with the exact error and failure code."}

## `error.ingest_row_validation`
{"algorithm":["Write schema-invalid rows to the rejected CSV and continue ingest processing."],"edge_cases":["One or more rejected rows do not make ingest exit with an error."],"errors":[{"condition":"A row fails schema validation during ingest.","exit_code":null,"stderr":null,"stdout":null}],"output_schema":[{"key":"rejected_destination","value":"<output>.rejected"}],"summary":"Treat ingest row validation failures as rejected data, not command failures."}

## `error.invalid_recipe`
{"algorithm":["Validate operation names and referenced columns for filter, sort, aggregate, and join.","Terminate on invalid recipe detail."],"errors":[{"condition":"Unknown op or non-existent column referenced by filter, sort, aggregate, or join, except where a more specific exact join-key error applies.","exit_code":1,"stderr":"ERROR: invalid recipe: <detail>","stdout":null}],"summary":"Reject unknown recipe operations and invalid recipe column references with a standardized error."}

## `error.malformed_json`
{"algorithm":["Parse JSON inputs and terminate when parsing fails."],"errors":[{"condition":"A config, schema, or recipe file contains malformed JSON.","exit_code":1,"stderr":"ERROR: malformed JSON: <path>","stdout":null}],"summary":"Reject malformed JSON configuration, schema, or recipe files with the exact path-bearing error."}

## `error.invalid_schema_regex`
{"algorithm":["Compile schema pattern values as Go regular expressions.","Terminate if compilation fails."],"errors":[{"condition":"A schema pattern is not a valid Go regular expression.","exit_code":1,"stderr":"ERROR: invalid pattern: <pattern>","stdout":null}],"summary":"Reject invalid schema regular expressions with the exact pattern-bearing error."}

## `build.go_command`
{"algorithm":["Execute go build -o dpipe ./...."],"integration":[{"key":"build_system","value":"Go toolchain"}],"interface":[{"key":"working_directory","value":"/app/"},{"key":"build_command","value":"go build -o dpipe ./..."},{"key":"output_binary","value":"dpipe"}],"invariants":["The repository is buildable using the exact command from /app/."],"preconditions":["Run from /app/."],"summary":"Build dpipe from /app with the prescribed Go command."}

[EXPLICIT DEPENDENCIES]

_None._

[EXECUTION ANCHORS]

_None._

[PRIOR STATE PRESERVATION]

Preserved active requirements: 0
Preserved-state SHA-256: 4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945
All behavior already implemented in the persistent project remains normative unless the current transition explicitly supersedes it.
Do not regress, remove, or reinterpret unaffected behavior.
Use the existing implementation and regression tests as the executable prior state.

[CURRENT SUPERSESSIONS]

_None._

[EXECUTION]

Implement this state transition in the existing project.
Preserve the prior state except where this contract explicitly supersedes it.
Run focused checks for the changed behavior, then the complete regression suite.
This transition contract is the complete task instruction; do not consult an earlier natural-language instruction.
