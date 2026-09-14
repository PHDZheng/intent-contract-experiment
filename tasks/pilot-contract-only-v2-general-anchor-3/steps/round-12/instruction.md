[INTENT CONTRACT V2 TRANSITION]

Compiled through round: 12
Normative clause coverage: 271/271
All rendered requirements are MUST requirements.
Transition slice: 4 touched + 0 explicit dependencies + 1 execution anchors.
Provenance and complete state are retained in the compiler audit artifacts, not repeated here.

[CURRENT TRANSITION SPECIFICATION]

## `transform.normalize`
{"algorithm":["Collect all non-empty source values that parse as float64; let n be their count.","Resolve the effective method: use minmax when method is omitted or empty; otherwise use the explicit zscore or minmax method.","For zscore, compute mean and sample standard deviation with denominator n-1.","For minmax, including the omitted-or-empty default path, compute min and max over the collected numeric values.","For each row, emit empty string if the source cell is empty or does not parse as a float.","For zscore, if n<2 or sample standard deviation is 0, emit 0 for every float-parseable source value; otherwise emit (x-mean)/stddev.","For explicit minmax and the default minmax path, if min==max, emit 0 for every float-parseable source value; otherwise emit (x-min)/(max-min)."],"defaults":[{"key":"method","value":"minmax when omitted or empty"}],"edge_cases":["Empty or unparsable source cells produce empty strings.","For default or explicit minmax, a non-empty numeric set with min==max produces \"0\" for every numeric row and does not divide by zero.","For zscore, n<2 or sample standard deviation 0 produces \"0\" for every numeric row.","Omitting method and supplying method as an empty string have identical behavior."],"errors":[{"condition":"column does not exist.","exit_code":1,"stderr":"ERROR: invalid recipe: column <name> not found","stdout":null}],"formatting":[{"key":"numeric_result","value":"Go strconv.FormatFloat(val, 'f', -1, 64)."},{"key":"zero","value":"Literal string \"0\", not \"0.0\"."}],"formulas":[{"key":"mean","value":"sum(xi) / n"},{"key":"zscore_sample_stddev","value":"sqrt(sum((xi - mean)^2) / (n - 1))"},{"key":"zscore","value":"(x - mean) / stddev"},{"key":"minmax","value":"(x - min) / (max - min)"},{"key":"effective_method","value":"method omitted or method == \"\" ? \"minmax\" : method"}],"input_schema":[{"key":"op","value":"normalize"},{"key":"column","value":"Existing source column."},{"key":"method","value":"Explicitly \"zscore\" or \"minmax\"; an omitted field or empty string selects minmax."},{"key":"as","value":"Name of the new last column."},{"key":"numeric_parser","value":"Go strconv.ParseFloat(value, 64)."}],"invariants":["Explicit zscore behavior remains unchanged.","Explicit minmax behavior remains unchanged.","The profile command's stddev remains a population standard deviation; normalize zscore continues to use sample standard deviation."],"ordering":["Preserve row order and all original columns; append as as the last column."],"output_schema":[{"key":"as","value":"Appended last column containing a normalized numeric string or empty string."}],"summary":"Append z-score or min-max normalized values, defaulting an omitted or empty method to minmax while preserving explicit zscore and minmax behavior."}

## `transform.round_interface_and_layout`
{"algorithm":["Resolve the source column.","Process every row in current dataset order.","If the source cell is empty, emit an empty string in the new column.","Otherwise parse the source value as a float.","If parsing fails, emit an empty string in the new column.","If parsing succeeds, round and serialize the value using the round computation and formatting requirement.","Append the result under the column name supplied by as."],"edge_cases":["An empty source cell remains empty in the appended column.","A non-empty source cell that cannot be parsed as a float produces an empty appended cell.","n may be 0."],"formatting":[{"key":"empty_or_non_numeric_result","value":"Literal empty string."}],"input_schema":[{"key":"op","value":"round"},{"key":"column","value":"String name of the source column containing numeric values."},{"key":"n","value":"Integer number of decimal places; must be 0 or greater."},{"key":"as","value":"String name of the new column to append."},{"key":"recipe","value":"{\"op\":\"round\",\"column\":\"price\",\"n\":2,\"as\":\"price_rounded\"}"}],"integration":[{"key":"recipe_execution","value":"Runs as one operation in the ordered transform recipe chain."}],"invariants":["Exactly one new column is appended.","Existing source and other columns are not modified."],"ordering":["Preserve the current row order and all existing column order.","Append as after all existing columns."],"output_schema":[{"key":"as","value":"New last column containing the rounded fixed-decimal string or an empty string."}],"preconditions":["n is an integer greater than or equal to 0."],"summary":"Provide a round transform that parses one source column and appends a rounded result column while representing empty or non-numeric inputs as empty strings."}

## `round.computation_and_formatting`
{"algorithm":["Round the parsed value to n decimal places.","When the value is exactly halfway between adjacent values at the requested decimal precision, choose the value farther from zero.","Serialize the rounded result using fixed-point notation with exactly n digits after the decimal point."],"edge_cases":["Positive and negative half-values round away from zero.","Trailing zeros required to reach exactly n fractional digits must be written.","An empty or non-numeric source cell is handled by the round interface requirement and is not numerically rounded."],"examples":[{"input":"{\"op\":\"round\",\"column\":\"price\",\"n\":2,\"as\":\"price_rounded\"}","name":"round recipe","notes":"Numeric price values are rounded half away from zero and written with exactly two fractional digits.","output":""}],"formatting":[{"key":"fractional_digits","value":"Exactly n digits after the decimal point."},{"key":"n_zero","value":"When n is 0, write no decimal point or fractional digits."},{"key":"rounding_mode","value":"Half away from zero."}],"formulas":[{"key":"scale","value":"10^n"},{"key":"rounded_value","value":"half_away_from_zero(value * 10^n) / 10^n"}],"input_schema":[{"key":"value","value":"A source-cell value successfully parsed as a float."},{"key":"n","value":"A non-negative integer number of decimal places."}],"integration":[{"key":"consumer","value":"The transform.round_interface_and_layout requirement invokes this behavior for every successfully parsed numeric source cell."}],"invariants":["Every numeric result has exactly the requested number of fractional digits."],"output_schema":[{"key":"result","value":"The rounded value rendered with exactly n digits after the decimal point."}],"preconditions":["The source value parsed successfully as a float.","n is an integer greater than or equal to 0."],"summary":"Round each parsed numeric value to n decimal places using half-away-from-zero behavior and write exactly n fractional digits."}

## `round.missing_column_error`
{"algorithm":["Validate column against the current dataset header before processing rows.","Terminate when the configured source column is absent."],"errors":[{"condition":"The round source column does not exist in the current dataset.","exit_code":1,"stderr":"ERROR: invalid recipe: column <name> not found","stdout":null}],"input_schema":[{"key":"column","value":"Configured round source-column name."}],"integration":[{"key":"standard_error","value":"Uses the established invalid-recipe missing-column diagnostic."}],"invariants":["No rounded output is produced after this error."],"summary":"Fail a round transform when its configured source column is absent."}

[EXPLICIT DEPENDENCIES]

_None._

[EXECUTION ANCHORS]

## `build.go_command`
{"algorithm":["Execute go build -o dpipe ./...."],"integration":[{"key":"build_system","value":"Go toolchain"}],"interface":[{"key":"working_directory","value":"/app/"},{"key":"build_command","value":"go build -o dpipe ./..."},{"key":"output_binary","value":"dpipe"}],"invariants":["The repository is buildable using the exact command from /app/."],"preconditions":["Run from /app/."],"summary":"Build dpipe from /app with the prescribed Go command."}


[PRIOR STATE PRESERVATION]

Preserved active requirements: 193
Preserved-state SHA-256: 38aee368e80348e405a910dfe594ec1674d3be06bbad6645c9ecbdd6af6e39bd
All behavior already implemented in the persistent project remains normative unless the current transition explicitly supersedes it.
Do not regress, remove, or reinterpret unaffected behavior.
Use the existing implementation and regression tests as the executable prior state.

[CURRENT SUPERSESSIONS]

- `transform.normalize`: replace prior behavior with the current specification above.

[EXECUTION]

Implement this state transition in the existing project.
Preserve the prior state except where this contract explicitly supersedes it.
Run focused checks for the changed behavior, then the complete regression suite.
This transition contract is the complete task instruction; do not consult an earlier natural-language instruction.
