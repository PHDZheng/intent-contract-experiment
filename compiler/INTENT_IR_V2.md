# Intent IR v2

Intent IR v2 changes the compiler target from a concise requirement ledger to
a replacement-grade executable specification. New compilation chains start at
version 2; existing version 1 IR and contracts remain readable and renderable.

## Guarantees

- The host deterministically partitions every instruction into verbatim clause
  blocks. Concatenating the stored blocks reproduces the instruction exactly.
- Every block receives exactly one `normative`, `example`, or `context`
  disposition.
- Every normative block maps to at least one requirement, and every new
  operation has a reciprocal normative source mapping.
- Every non-unknown requirement carries a structured `spec` with a summary and
  at least one executable detail category.
- Active semantic keys are unique. Revisions retain the complete supersession
  history and may target only an active requirement with the same key.
- Source rounds, offsets, text, and SHA-256 values are checked against the
  verbatim ledger; future-round references are rejected.

## Structured specification

The v2 `spec` supports interfaces, input/output schemas, preconditions,
algorithm steps, formulas, defaults, ordering, formatting, edge cases, exact
errors, examples, integrations, invariants, and notes. The semantic compiler is
instructed to use atomic keys and preserve all independently testable details.

The compiler does not infer interface or schema renames from an implementation
or algorithm change. Names change only when the source instruction supports
that change; ambiguity is retained rather than resolved using benchmark tests,
reference implementations, or domain-specific naming conventions.

## Contract-only materialization

Create a new task without placing original instructions in the Coding Agent
input:

```bash
intent-materialize-task SOURCE_TASK DESTINATION_TASK COMPILED_ARTIFACTS \
  --name contract-only-v2 \
  --instruction-mode contract-only
```

Validate that every materialized instruction exactly equals its compiled
contract and that all other task files remain unchanged:

```bash
intent-validate-task-copy SOURCE_TASK DESTINATION_TASK \
  --instruction-mode contract-only \
  --compiled-directory COMPILED_ARTIFACTS
```

Append mode remains available with `--instruction-mode append` and is the
default.

## Compact execution profile

The full IR remains the lossless audit artifact. For repeated agent execution,
render a compact contract that keeps every non-empty active specification,
provenance clause ID, and tombstone while omitting repeated verbatim evidence,
empty schema fields, and per-requirement instruction hashes:

```bash
intent-materialize-task SOURCE_TASK DESTINATION_TASK COMPILED_ARTIFACTS \
  --name contract-only-v2-compact \
  --instruction-mode contract-only \
  --contract-profile compact
```

An already validated v2 compilation can be re-rendered without another semantic
model call:

```bash
intent-materialize-task SOURCE_TASK DESTINATION_TASK NEW_COMPILED_ARTIFACTS \
  --name contract-only-v2-compact \
  --instruction-mode contract-only \
  --contract-profile compact \
  --reuse-compiled PREVIOUS_COMPILED_ARTIFACTS
```

## Focused execution profile

For sequential execution, the focused profile derives a smaller per-round view
from the validated IR and current delta. It renders every requirement touched by
the current round in full, expands requirements referenced by exact ID or
semantic key, lists every other active requirement in a normative preservation
index, and retains all supersession tombstones:

```bash
intent-materialize-task SOURCE_TASK DESTINATION_TASK NEW_COMPILED_ARTIFACTS \
  --name contract-only-v2-focused \
  --instruction-mode contract-only \
  --contract-profile focused \
  --reuse-compiled PREVIOUS_COMPILED_ARTIFACTS
```

The complete `intent_ir.json` remains the authority. Each focused artifact also
contains `intent_view.json`, which records the touched, detailed dependency,
preserved, and superseded requirement IDs. This makes prompt slicing
deterministic and auditable without consulting the original natural-language
instruction at execution time.

## Transition execution profile

For a persistent sequential workspace, the transition profile treats each round
as a state change instead of reprinting the full current state. Round 1 supplies
the complete initialization because all requirements are touched. Later rounds
render only current touched requirements, requirements referenced by exact ID or
semantic key, stable build/execution anchors, and supersessions that occur in
that round:

```bash
intent-materialize-task SOURCE_TASK DESTINATION_TASK NEW_COMPILED_ARTIFACTS \
  --name contract-only-v2-transition \
  --instruction-mode contract-only \
  --contract-profile transition \
  --reuse-compiled PREVIOUS_COMPILED_ARTIFACTS
```

Other unchanged active requirements are not repeated in the agent prompt. They remain
normative through the persistent implementation and regression suite. The
generated `intent_view.json` records every preserved requirement and a SHA-256
digest over its complete canonical IR records. It also records execution-anchor
requirement IDs selected by the `build.*` and `execution.*` semantic-key
namespaces. Provenance, clause IDs, source
rounds, and the complete supersession graph remain in `intent_ir.json`; the
execution prompt contains executable semantics only.

This profile is appropriate only when rounds execute sequentially against the
same persistent project state. A stateless single-round consumer must use the
focused or compact profile instead.

## Compatibility and migration

Version 1 IR is accepted by `validate_ir` and `render_active_ir`; it is not
silently converted because its summarized values do not contain enough data to
construct a lossless v2 specification. Recompile from the original sequential
instructions into a new artifact directory to obtain v2. Never overwrite the
existing v1 experiment artifacts.

## Validation boundary

Mechanical validation proves lossless source partitioning, complete normative
clause mapping, provenance, internal consistency, authorized task
materialization, and deterministic focused-view membership. Classification,
summary or persistent-state sufficiency for preserved requirements, and semantic
equivalence still require review or evaluation. A production claim that
contracts replace source instructions should additionally use Gold IR audits
and repeated Contract-only benchmark trials.
