"""Invoke Codex for semantic extraction, then validate and merge locally."""
from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable, Mapping

from clause_segments import segment_instruction
from merge_ir import merge_ir
from validate_delta import (ROOT, ValidationError, load_json, normalize_ledger,
                            sha256_text, validate_delta)


def empty_ir() -> dict[str, Any]:
    return {"version": 2, "compiled_through_round": 0, "clauses": [], "requirements": []}


def build_prompt(previous_ir: Mapping[str, Any], instruction: str,
                 ledger: Any, current_round: int) -> str:
    sources = normalize_ledger(ledger)
    if sources.get(current_round) != instruction:
        raise ValueError("current instruction must exactly match its ledger entry")
    if any(r > current_round for r in sources):
        raise ValueError("future-round leakage in source ledger")
    policy = (ROOT / "compiler_prompt.md").read_text(encoding="utf-8")
    payload = {
        "current_round": current_round,
        "current_instruction_sha256": sha256_text(instruction),
        "previous_intent_ir": previous_ir,
        "current_verbatim_instruction": instruction,
        "current_instruction_clauses": segment_instruction(instruction, current_round),
        "source_ledger": [
            {
                "round": r,
                "instruction": sources[r],
                "instruction_sha256": sha256_text(sources[r]),
            }
            for r in sorted(sources)
        ],
    }
    return policy + "\n\n<compiler-input>\n" + json.dumps(payload, ensure_ascii=False) + "\n</compiler-input>\n"


def codex_semantic_compile(prompt: str, *, codex_command: str = "codex") -> dict[str, Any]:
    """Run non-interactive Codex with enforced structured output."""
    with tempfile.TemporaryDirectory(prefix="intent-compiler-") as temp:
        output = Path(temp) / "delta.json"
        command = [codex_command, "exec", "--skip-git-repo-check",
                   "--output-schema", str(ROOT / "intent_delta.schema.json"),
                   "--output-last-message", str(output), "-"]
        completed = subprocess.run(command, input=prompt, text=True, capture_output=True, check=False)
        if completed.returncode:
            raise RuntimeError(f"Codex semantic compilation failed: {completed.stderr.strip()}")
        try:
            return json.loads(output.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise RuntimeError("Codex did not produce a valid structured delta") from exc


def compile_round(previous_ir: Mapping[str, Any], instruction: str, ledger: Any,
                  current_round: int,
                  semantic_compiler: Callable[[str], Mapping[str, Any]] | None = None) -> dict[str, Any]:
    _, ir = compile_round_artifacts(
        previous_ir, instruction, ledger, current_round, semantic_compiler
    )
    return ir


def compile_round_artifacts(
    previous_ir: Mapping[str, Any],
    instruction: str,
    ledger: Any,
    current_round: int,
    semantic_compiler: Callable[[str], Mapping[str, Any]] | None = None,
    max_validation_attempts: int = 3,
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Return both the validated semantic delta and deterministically merged IR."""
    if max_validation_attempts < 1:
        raise ValueError("max_validation_attempts must be positive")
    prompt = build_prompt(previous_ir, instruction, ledger, current_round)
    compiler = semantic_compiler or codex_semantic_compile
    for attempt in range(1, max_validation_attempts + 1):
        # The deterministic layer validates and merges model output but never
        # rewrites domain semantics. Any normalization that changes names or
        # behavior must be explicitly grounded in the supplied instruction.
        delta = dict(compiler(prompt))
        try:
            validate_delta(delta, previous_ir, ledger, current_round)
            break
        except ValidationError as exc:
            if attempt == max_validation_attempts:
                raise
            prompt += (
                "\n<validation-feedback>\n"
                "Your preceding delta was rejected by the deterministic validator. "
                "Regenerate the complete delta for the unchanged compiler input.\n"
                f"attempt: {attempt}\nerror: {exc}\n"
                "rejected_delta:\n" + json.dumps(delta, ensure_ascii=False) +
                "\n</validation-feedback>\n"
            )
    return delta, merge_ir(previous_ir, delta, ledger, current_round)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("previous_ir")
    parser.add_argument("instruction")
    parser.add_argument("ledger")
    parser.add_argument("--round", type=int, required=True)
    parser.add_argument("-o", "--output")
    parser.add_argument("--codex-command", default="codex")
    args = parser.parse_args()
    instruction = Path(args.instruction).read_text(encoding="utf-8")
    compiler = lambda prompt: codex_semantic_compile(prompt, codex_command=args.codex_command)
    result = compile_round(load_json(args.previous_ir), instruction, load_json(args.ledger), args.round, compiler)
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        Path(args.output).write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
