"""Copy and compile every round of a Harbor multi-step task."""
from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path
from typing import Any, Callable, Mapping

from compile_round import codex_semantic_compile, compile_round_artifacts, empty_ir
from render_active_ir import focused_view, render_active_ir, transition_view
from validate_delta import load_json, validate_ir

ROUND_RE = re.compile(r"round-(\d+)$")


def _rounds(task: Path) -> list[tuple[int, Path]]:
    found = []
    for path in (task / "steps").glob("round-*"):
        match = ROUND_RE.fullmatch(path.name)
        if match and (path / "instruction.md").is_file():
            found.append((int(match.group(1)), path))
    found.sort()
    if not found or [n for n, _ in found] != list(range(1, len(found) + 1)):
        raise ValueError("task rounds must be contiguous and start at 1")
    return found


def _rename_metadata(task: Path, new_name: str) -> None:
    candidates = [task / n for n in ("task.toml", "task.yaml", "task.yml", "task.json") if (task / n).is_file()]
    if not candidates:
        return
    path = candidates[0]
    text = path.read_text(encoding="utf-8")
    if path.suffix == ".json":
        data = json.loads(text)
        data["name"] = new_name
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    else:
        updated, count = re.subn(r"(?m)^(name\s*[:=]\s*)([^\n#]+)", lambda m: m.group(1) + ('"' + new_name + '"' if path.suffix == ".toml" else new_name), text, count=1)
        if count != 1:
            raise ValueError(f"metadata has no top-level name: {path}")
        path.write_text(updated, encoding="utf-8")


def _write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")


def materialize_task(source: str | Path, destination: str | Path,
                     compiled_directory: str | Path, *, new_name: str | None = None,
                     semantic_compiler: Callable[[str], Mapping[str, Any]] | None = None,
                     instruction_mode: str = "append",
                     contract_profile: str = "full") -> dict[str, Any]:
    source, destination, compiled_directory = Path(source), Path(destination), Path(compiled_directory)
    if instruction_mode not in {"append", "contract-only"}:
        raise ValueError("instruction_mode must be 'append' or 'contract-only'")
    if contract_profile not in {"full", "compact", "focused", "transition"}:
        raise ValueError("contract_profile must be 'full', 'compact', 'focused', or 'transition'")
    if destination.exists():
        raise FileExistsError(destination)
    if compiled_directory.exists():
        raise FileExistsError(compiled_directory)
    shutil.copytree(source, destination)
    try:
        compiled_directory.mkdir(parents=True)
        if new_name:
            _rename_metadata(destination, new_name)
        rounds = _rounds(destination)
        originals = {n: (path / "instruction.md").read_text(encoding="utf-8") for n, path in rounds}
        ir = empty_ir()
        ledger: dict[int, str] = {}
        for number, path in rounds:
            instruction = originals[number]
            ledger[number] = instruction
            delta, ir = compile_round_artifacts(
                ir, instruction, ledger, number, semantic_compiler
            )
            contract = render_active_ir(ir, profile=contract_profile, delta=delta)
            artifact_round = compiled_directory / f"round-{number:02d}"
            artifact_round.mkdir()
            _write_json(artifact_round / "intent_delta.json", delta)
            _write_json(artifact_round / "intent_ir.json", ir)
            if contract_profile == "focused":
                _write_json(artifact_round / "intent_view.json", focused_view(ir, delta))
            elif contract_profile == "transition":
                _write_json(artifact_round / "intent_view.json", transition_view(ir, delta))
            (artifact_round / "intent_contract.md").write_text(contract, encoding="utf-8")
            if instruction_mode == "contract-only":
                materialized = contract
            else:
                separator = "" if instruction.endswith("\n") else "\n"
                materialized = instruction + separator + "\n" + contract
            (path / "instruction.md").write_text(materialized, encoding="utf-8")
        return ir
    except Exception:
        shutil.rmtree(destination)
        if compiled_directory.exists():
            shutil.rmtree(compiled_directory)
        raise


def materialize_task_from_compiled(source: str | Path, destination: str | Path,
                                   compiled_input: str | Path, compiled_directory: str | Path,
                                   *, new_name: str | None = None,
                                   contract_profile: str = "compact") -> dict[str, Any]:
    """Re-render a task from validated IR without invoking the semantic compiler."""
    source, destination = Path(source), Path(destination)
    compiled_input, compiled_directory = Path(compiled_input), Path(compiled_directory)
    if contract_profile not in {"full", "compact", "focused", "transition"}:
        raise ValueError("contract_profile must be 'full', 'compact', 'focused', or 'transition'")
    if destination.exists():
        raise FileExistsError(destination)
    if compiled_directory.exists():
        raise FileExistsError(compiled_directory)
    shutil.copytree(source, destination)
    try:
        compiled_directory.mkdir(parents=True)
        if new_name:
            _rename_metadata(destination, new_name)
        rounds = _rounds(destination)
        final_ir: dict[str, Any] | None = None
        for number, path in rounds:
            input_round = compiled_input / f"round-{number:02d}"
            ir = load_json(input_round / "intent_ir.json")
            delta = load_json(input_round / "intent_delta.json")
            validate_ir(ir)
            if ir["version"] != 2 or ir["compiled_through_round"] != number:
                raise ValueError(f"compiled IR round mismatch: {input_round}")
            contract = render_active_ir(ir, profile=contract_profile, delta=delta)
            output_round = compiled_directory / f"round-{number:02d}"
            output_round.mkdir()
            _write_json(output_round / "intent_delta.json", delta)
            _write_json(output_round / "intent_ir.json", ir)
            if contract_profile == "focused":
                _write_json(output_round / "intent_view.json", focused_view(ir, delta))
            elif contract_profile == "transition":
                _write_json(output_round / "intent_view.json", transition_view(ir, delta))
            (output_round / "intent_contract.md").write_text(contract, encoding="utf-8")
            (path / "instruction.md").write_text(contract, encoding="utf-8")
            final_ir = dict(ir)
        if final_ir is None:
            raise ValueError("task has no rounds")
        return final_ir
    except Exception:
        shutil.rmtree(destination)
        if compiled_directory.exists():
            shutil.rmtree(compiled_directory)
        raise


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("destination")
    parser.add_argument("compiled_directory")
    parser.add_argument("--name")
    parser.add_argument("--codex-command", default="codex")
    parser.add_argument("--instruction-mode", choices=("append", "contract-only"), default="append")
    parser.add_argument("--contract-profile", choices=("full", "compact", "focused", "transition"), default="full")
    parser.add_argument("--reuse-compiled", help="validated v2 artifacts to re-render without compilation")
    args = parser.parse_args()
    if args.reuse_compiled:
        if args.instruction_mode != "contract-only":
            parser.error("--reuse-compiled requires --instruction-mode contract-only")
        ir = materialize_task_from_compiled(
            args.source, args.destination, args.reuse_compiled, args.compiled_directory,
            new_name=args.name, contract_profile=args.contract_profile,
        )
    else:
        compiler = lambda prompt: codex_semantic_compile(prompt, codex_command=args.codex_command)
        ir = materialize_task(
            args.source,
            args.destination,
            args.compiled_directory,
            new_name=args.name,
            semantic_compiler=compiler,
            instruction_mode=args.instruction_mode,
            contract_profile=args.contract_profile,
        )
    print(json.dumps(ir, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
