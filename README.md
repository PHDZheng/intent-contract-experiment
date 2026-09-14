# Intent Contract Experiment

[English](README.md) | [简体中文](README.zh-CN.md)

This repository is the public, reproducible package for the 15-round `dpipe`
sequential software-evolution experiment. It contains the Intent IR compiler,
the control and `v2 general-anchor` task variants, the exact compiled artifacts,
the evaluation utilities, and the Sol/Luna experiment report.

## Included scope

- `compiler/`: deterministic Intent IR/Delta validation, merge, rendering, and
  task-materialization code, plus unit tests.
- `tasks/pilot-control-3/`: the original 15-round Harbor task.
- `tasks/pilot-contract-only-v2-general-anchor-3/`: the materialized treatment
  task used by the valid `v2 general-anchor` experiment.
- `artifacts/simple-v2-general-anchor/`: each round's exact Delta, cumulative IR,
  execution view, and rendered contract.
- `evaluation/`: the Harbor runner and result aggregation utilities.
- `reports/`: the experiment report in Markdown and Word formats.
- `locks/`: versions/commits captured from the original experiment environment.

Generated runs, model trajectories, credentials, virtual environments, caches,
and large dataset archives are deliberately excluded. The rejected
`v2 schema-fixed-anchor` and `v3 transition-anchor` experiments are not included.

## Requirements

- Python 3.11 or newer
- [`uv`](https://docs.astral.sh/uv/) or `pip`
- Docker and Harbor for end-to-end benchmark execution
- A supported coding-agent runtime and its credentials for model runs

The recorded environment versions are available in `locks/`. Exact historical
model outputs are stochastic and may also depend on model availability; the
checked-in contracts and test fixtures are deterministic inputs.

## Validate the package

With `uv`:

```bash
make check
```

Or with standard Python tooling:

```bash
python -m venv .venv
. .venv/bin/activate
python -m pip install -e './compiler[test]'
python -m pytest -q compiler/tests
python compiler/validate_task_copy.py \
  tasks/pilot-control-3 \
  tasks/pilot-contract-only-v2-general-anchor-3 \
  --instruction-mode contract-only \
  --compiled-directory artifacts/simple-v2-general-anchor
```

The task-copy validator proves that only the task name and round instructions
changed, and that every treatment instruction is byte-identical to the checked-in
compiled contract for that round.

## Run the benchmark

First validate the Harbor task and its oracle solution:

```bash
./evaluation/run_single.sh \
  tasks/pilot-contract-only-v2-general-anchor-3 \
  oracle \
  --jobs-dir runs/general-anchor-oracle
```

Then run a coding agent. The following reproduces the recorded Sol configuration
when the corresponding model/runtime is available:

```bash
AGENT_TYPE=codex \
AGENT_MODEL=openai/gpt-5.6-sol \
AGENT_ATTEMPTS=1 \
HARBOR_N_CONCURRENT=1 \
AGENT_KWARGS='{"reasoning_effort":"medium"}' \
./evaluation/run_single.sh \
  tasks/pilot-contract-only-v2-general-anchor-3 \
  agent \
  --jobs-dir runs/general-anchor-sol
```

Do not commit the `runs/` directory: it may contain model transcripts, local
paths, or provider metadata. Aggregate completed Harbor outputs with:

```bash
python evaluation/compute_metrics.py \
  --tasks-dir tasks \
  --results-dir runs \
  --model gpt-5.6-sol
```

## Result reference

The recorded `v2 general-anchor` Sol run passed 11,009 of 11,034 accumulated
cases (99.77%) and fully passed 10 of 15 rounds, for a Harbor mean reward of
0.6667. The complete round-by-round table and the two optimization examples are
in [`reports/SOL_LUNA_OPTIMIZED_EXPERIMENT_REPORT.md`](reports/SOL_LUNA_OPTIMIZED_EXPERIMENT_REPORT.md).

## Reproducibility and disclosure

The task package contains verifier tests and oracle solutions so that the recorded
evaluation can be audited. Publishing such files may make this task unsuitable
for a blind public leaderboard; use a private test set for future held-out claims.

The compiler's semantic compilation path may invoke Codex. Re-running semantic
compilation can therefore vary, while validation, IR merging, rendering from
checked-in artifacts, and task-copy verification are deterministic.

## Licensing and provenance

The evaluation harness and task format are derived from EvoCodeBench. Its MIT
license is preserved in `third_party/EvoCodeBench-LICENSE`; see
`THIRD_PARTY_NOTICES.md`. No separate license is granted for the remaining
project-specific material unless the repository owner adds one.
