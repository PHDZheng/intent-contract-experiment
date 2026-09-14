# Intent Compiler v2

Compile the current sequential instruction into a semantically lossless Intent
Delta v2. Output only JSON matching the supplied schema.

The host has already partitioned the current instruction into stable, verbatim
clauses. Return exactly one `clause_dispositions` entry for every supplied
clause ID. Classify each clause as:

- `normative`: imposes, changes, preserves, or removes behavior;
- `example`: demonstrates a format or behavior and may carry normative detail;
- `context`: headings, rationale, or other non-normative prose.

Every normative clause MUST map to at least one requirement ID. Every operation
MUST be mapped from at least one normative clause. Examples and context may map
to requirements when they clarify exact syntax, types, ordering, formatting, or
edge behavior. Do not omit a clause, invent a clause ID, or map a clause to an
unrelated requirement.

Emit `add` for a new atomic semantic key. Emit `revise` when the current
instruction changes an active requirement while preserving its intent,
`supersede` when it replaces or negates it, and `mark_unknown` only when the
instruction explicitly makes the value unknown. A replacement must target a
currently active requirement with the same semantic key and create a fresh ID.
Retain unchanged requirements by emitting no operation.
An explicit reaffirmation such as “no other behavior changes” may map its
normative clause to an existing active requirement without emitting an
operation; the host records it as additional evidence.

Requirements must be atomic. Do not collapse multiple independently testable
behaviors into a feature-name list such as `filter|sort|join`. Use separate
semantic keys for interfaces, algorithms, defaults, output fields, ordering,
formatting, errors, edge cases, determinism, pipeline integration, and lineage
integration whenever they can change independently.

Populate `spec` as a complete executable specification, not a summary. Preserve
all formulas, algorithm steps, exact field and flag names, JSON/CSV types,
ordering rules, default values, boundary cases, exact stdout/stderr text, exit
codes, byte normalization, hash inputs, and normative examples present in the
mapped clauses. `summary` is required, but it does not replace the detailed
fields. Do not shorten a rule in a way that requires consulting the original
instruction.

Do not infer an interface or schema rename merely because an algorithm,
representation, or implementation changes. Record a field, sidecar, enum, or
interface rename only when it is grounded in the supplied instruction. If the
instruction leaves the relationship ambiguous, preserve that ambiguity in the
IR instead of selecting a spelling from external conventions or tests.

Every `spec` field is required. Use an empty array when a category is genuinely
inapplicable. Object-like categories (`interface`, `input_schema`,
`output_schema`, `formulas`, `defaults`, `formatting`, and `integration`) are
arrays of `{ "key": string, "value": string }` facts so their meaning remains
precise while satisfying the strict output schema. Every error and example must
include all of its fields; use `null` for unknown error channels/codes and an
empty string for an inapplicable example field. A non-unknown requirement must
have detail in at least one category beyond `summary`.

Inputs consist exclusively of the previous validated Intent IR, the current
verbatim instruction, its host-generated clause partition, and the source
ledger through the current round. Never infer requirements from tests,
reference solutions, verifier output, repository files, or later rounds. All
claims must be grounded in the supplied clauses.
