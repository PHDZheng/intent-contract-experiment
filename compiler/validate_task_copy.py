"""Prove that task materialization changed only authorized content."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


class TaskCopyError(ValueError):
    pass


INSTRUCTION_RE = re.compile(r"^steps/round-[0-9]+/instruction\.md$")
METADATA = {"task.toml", "task.yaml", "task.yml", "task.json"}
ACTIVE = "[CURRENT ACTIVE INTENT]\n\n"
SUPERSEDED = "\n[SUPERSEDED INTENT]\n\n"
EXECUTION = (
    "\n[EXECUTION]\n\n"
    "Implement the current request while preserving all active intent.\n"
    "Do not restore superseded behavior.\n"
)
V2_START = "[INTENT CONTRACT V2]\n\n"
V2_COMPACT_START = "[INTENT CONTRACT V2 COMPACT]\n\n"
V2_FOCUSED_START = "[INTENT CONTRACT V2 FOCUSED]\n\n"
V2_TRANSITION_START = "[INTENT CONTRACT V2 TRANSITION]\n\n"
V2_EXECUTION_END = (
    "[EXECUTION]\n\n"
    "Implement this contract as the complete specification for the current task state.\n"
    "Preserve every active specification and exact normative source clause.\n"
    "Do not restore behavior listed in superseded tombstones.\n"
    "Do not consult an earlier natural-language instruction to fill missing details.\n"
)
V2_COMPACT_EXECUTION_END = (
    "[EXECUTION]\n\n"
    "Implement this compact contract as the complete specification for the current task state.\n"
    "Every non-empty normalized field above is normative; omitted fields are empty, not unknown.\n"
    "Clause IDs provide provenance without repeating source text in the execution prompt.\n"
    "Do not restore behavior listed in superseded tombstones.\n"
    "Do not consult an earlier natural-language instruction to fill missing details.\n"
)
V2_FOCUSED_EXECUTION_END = (
    "[EXECUTION]\n\n"
    "Implement the current-round specification and its detailed dependencies.\n"
    "Preserve every behavior named in the active preservation index; unchanged indexed behavior remains normative.\n"
    "Do not restore behavior listed in superseded tombstones.\n"
    "This focused contract is the complete task instruction; do not consult an earlier natural-language instruction.\n"
)
V2_TRANSITION_EXECUTION_END = (
    "[EXECUTION]\n\n"
    "Implement this state transition in the existing project.\n"
    "Preserve the prior state except where this contract explicitly supersedes it.\n"
    "Run focused checks for the changed behavior, then the complete regression suite.\n"
    "This transition contract is the complete task instruction; do not consult an earlier natural-language instruction.\n"
)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _files(root: Path) -> dict[str, Path]:
    return {p.relative_to(root).as_posix(): p for p in root.rglob("*") if p.is_file()}


def _without_metadata_name(path: Path) -> object:
    text = path.read_text(encoding="utf-8")
    if path.suffix == ".json":
        data = json.loads(text)
        if not isinstance(data, dict) or "name" not in data:
            raise TaskCopyError("JSON metadata lacks name")
        data = dict(data)
        data["name"] = "<TASK_NAME>"
        return data
    normalized, count = re.subn(r"(?m)^name\s*([:=])\s*([^\n#]+)", r"name\1<TASK_NAME>", text, count=1)
    if count != 1:
        raise TaskCopyError(f"metadata lacks top-level name: {path.name}")
    return normalized


def _validate_requirement_section(section: str, label: str) -> None:
    if section.endswith("\n"):
        section = section[:-1]
    if section == "_None._":
        return
    lines = section.splitlines()
    if not lines or any(not line.startswith("- [") for line in lines):
        raise TaskCopyError(f"invalid {label} intent section")
    for line in lines:
        if not re.search(r"\(round [0-9]+, sha256 [0-9a-f]{64}(?:, supersedes [^)]+)?\)", line):
            raise TaskCopyError(f"intent entry lacks valid provenance in {label} section")


def _validate_contract(contract: str, round_no: int) -> None:
    if contract.startswith((V2_START, V2_COMPACT_START, V2_FOCUSED_START, V2_TRANSITION_START)):
        if contract.startswith(V2_TRANSITION_START):
            required = (
                "[CURRENT TRANSITION SPECIFICATION]\n",
                "[EXPLICIT DEPENDENCIES]\n",
                "[PRIOR STATE PRESERVATION]\n",
                "[CURRENT SUPERSESSIONS]\n",
                "[EXECUTION]\n",
            )
            expected_end = V2_TRANSITION_EXECUTION_END
            digest = re.search(r"Preserved-state SHA-256: ([0-9a-f]{64})", contract)
            if digest is None:
                raise TaskCopyError("transition contract lacks preserved-state digest")
            if contract.count("[EXECUTION ANCHORS]\n") > 1:
                raise TaskCopyError("invalid transition execution anchors")
        elif contract.startswith(V2_FOCUSED_START):
            required = (
                "[CURRENT ROUND EXECUTION SPECIFICATION]\n",
                "[RELEVANT DEPENDENCY SPECIFICATION]\n",
                "[ACTIVE PRESERVATION INDEX]\n",
                "[SUPERSEDED TOMBSTONES]\n",
                "[EXECUTION]\n",
            )
            expected_end = V2_FOCUSED_EXECUTION_END
        else:
            required = ("[CURRENT ACTIVE SPECIFICATION]\n", "[SUPERSEDED TOMBSTONES]\n", "[EXECUTION]\n")
            expected_end = V2_COMPACT_EXECUTION_END if contract.startswith(V2_COMPACT_START) else V2_EXECUTION_END
        if any(contract.count(marker) != 1 for marker in required) or not contract.endswith(expected_end):
            raise TaskCopyError("invalid v2 Intent Contract wrapper")
        coverage = re.search(r"Normative clause coverage: ([0-9]+)/([0-9]+)", contract)
        if coverage is None or coverage.group(1) != coverage.group(2):
            raise TaskCopyError("incomplete normative clause coverage")
        cited = [int(value) for value in re.findall(r"source round: ([0-9]+)", contract)]
        tombstones = [int(value) for value in re.findall(r"\(round ([0-9]+)\)", contract)]
        if any(value > round_no for value in cited + tombstones):
            raise TaskCopyError("future-round leakage in Intent Contract")
        return
    if not contract.startswith(ACTIVE) or not contract.endswith(EXECUTION):
        raise TaskCopyError("invalid Intent Contract wrapper")
    content = contract[len(ACTIVE):-len(EXECUTION)]
    if content.count(SUPERSEDED) != 1:
        raise TaskCopyError("invalid Intent Contract sections")
    active, superseded = content.split(SUPERSEDED, 1)
    _validate_requirement_section(active, "ACTIVE")
    _validate_requirement_section(superseded, "SUPERSEDED")
    cited_rounds = [int(value) for value in re.findall(r"\(round ([0-9]+), sha256", contract)]
    superseded_rounds = [int(value) for value in re.findall(r"→ [^\n]+ \(round ([0-9]+)\)", contract)]
    if any(value > round_no for value in cited_rounds + superseded_rounds):
        raise TaskCopyError("future-round leakage in Intent Contract")


def _validate_instruction_append(source_path: Path, copy_path: Path, round_no: int) -> None:
    original = source_path.read_bytes()
    treatment = copy_path.read_bytes()
    if not treatment.startswith(original):
        raise TaskCopyError(f"treatment instruction does not preserve original bytes: {source_path}")
    suffix_bytes = treatment[len(original):]
    expected_separator = b"\n" if original.endswith(b"\n") else b"\n\n"
    if not suffix_bytes.startswith(expected_separator):
        raise TaskCopyError(f"invalid Intent Contract separator: {source_path}")
    try:
        contract = suffix_bytes[len(expected_separator):].decode("utf-8")
    except UnicodeDecodeError as exc:
        raise TaskCopyError(f"Intent Contract is not UTF-8: {source_path}") from exc
    _validate_contract(contract, round_no)


def validate_task_copy(source: str | Path, copy: str | Path, *, instruction_mode: str = "append",
                       compiled_directory: str | Path | None = None) -> None:
    source, copy = Path(source), Path(copy)
    if instruction_mode not in {"append", "contract-only"}:
        raise TaskCopyError("invalid instruction mode")
    compiled = Path(compiled_directory) if compiled_directory is not None else None
    if instruction_mode == "contract-only" and compiled is None:
        raise TaskCopyError("contract-only validation requires compiled_directory")
    left, right = _files(source), _files(copy)
    if set(left) != set(right):
        missing = sorted(set(left) - set(right))
        extra = sorted(set(right) - set(left))
        raise TaskCopyError(f"file set differs; missing={missing}, extra={extra}")
    for relative in sorted(left):
        instruction_match = INSTRUCTION_RE.fullmatch(relative)
        if instruction_match:
            round_no = int(relative.split("/")[1].removeprefix("round-"))
            if instruction_mode == "append":
                _validate_instruction_append(left[relative], right[relative], round_no)
            else:
                expected = compiled / f"round-{round_no:02d}" / "intent_contract.md"
                if not expected.is_file() or file_sha256(expected) != file_sha256(right[relative]):
                    raise TaskCopyError(f"instruction is not the compiled contract: {relative}")
                _validate_contract(right[relative].read_text(encoding="utf-8"), round_no)
            continue
        if file_sha256(left[relative]) == file_sha256(right[relative]):
            continue
        if relative in METADATA and _without_metadata_name(left[relative]) == _without_metadata_name(right[relative]):
            continue
        raise TaskCopyError(f"unauthorized difference: {relative}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("copy")
    parser.add_argument("--instruction-mode", choices=("append", "contract-only"), default="append")
    parser.add_argument("--compiled-directory")
    args = parser.parse_args()
    try:
        validate_task_copy(args.source, args.copy, instruction_mode=args.instruction_mode,
                           compiled_directory=args.compiled_directory)
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
    print("PASS")


if __name__ == "__main__":
    main()
