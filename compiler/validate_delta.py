"""Deterministic validation for v1 and semantically lossless v2 Intent IR."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any, Mapping

from jsonschema import Draft202012Validator

from clause_segments import segment_instruction

ROOT = Path(__file__).resolve().parent


class ValidationError(ValueError):
    pass


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def load_json(path: str | Path) -> Any:
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def normalize_ledger(ledger: Any) -> dict[int, str]:
    """Accept only narrow round-to-verbatim-instruction ledger shapes."""
    if isinstance(ledger, dict) and "instructions" in ledger:
        if set(ledger) != {"instructions"}:
            raise ValidationError("ledger may contain only 'instructions'")
        ledger = ledger["instructions"]
    if isinstance(ledger, dict):
        result: dict[int, str] = {}
        for key, value in ledger.items():
            if not isinstance(value, str):
                raise ValidationError("ledger instruction must be a string")
            try:
                round_no = int(key)
            except (TypeError, ValueError) as exc:
                raise ValidationError("ledger round must be an integer") from exc
            result[round_no] = value
        return result
    if isinstance(ledger, list):
        result = {}
        for entry in ledger:
            if not isinstance(entry, dict) or set(entry) != {"round", "instruction"}:
                raise ValidationError("ledger entries require only round and instruction")
            if not isinstance(entry["round"], int) or not isinstance(entry["instruction"], str):
                raise ValidationError("invalid ledger entry types")
            if entry["round"] in result:
                raise ValidationError("duplicate ledger round")
            result[entry["round"]] = entry["instruction"]
        return result
    raise ValidationError("invalid source ledger")


def _schema(name: str) -> dict[str, Any]:
    return load_json(ROOT / name)


def _validate_schema(value: Mapping[str, Any], name: str, label: str) -> None:
    errors = sorted(Draft202012Validator(_schema(name)).iter_errors(value), key=lambda e: list(e.path))
    if errors:
        raise ValidationError(f"invalid {label}: {errors[0].message}")


def validate_ir(ir: Mapping[str, Any], *, current_round: int | None = None,
                ledger: Any | None = None) -> None:
    version = ir.get("version")
    if version == 1:
        _validate_ir_v1(ir, current_round=current_round, ledger=ledger)
    elif version == 2:
        _validate_ir_v2(ir, current_round=current_round, ledger=ledger)
    else:
        raise ValidationError(f"unsupported Intent IR version: {version}")


def _validate_ir_v1(ir: Mapping[str, Any], *, current_round: int | None,
                    ledger: Any | None) -> None:
    _validate_schema(ir, "intent_ir_v1.schema.json", "Intent IR")
    ids: set[str] = set()
    active_by_key: dict[str, str] = {}
    sources = normalize_ledger(ledger) if ledger is not None else None
    if current_round is not None and ir["compiled_through_round"] > current_round:
        raise ValidationError("future-round leakage in IR")
    for req in ir["requirements"]:
        if req["id"] in ids:
            raise ValidationError(f"duplicate ID: {req['id']}")
        ids.add(req["id"])
        if current_round is not None and req["source_round"] > current_round:
            raise ValidationError(f"future-round leakage: {req['id']}")
        if sources is not None:
            _validate_v1_source(req, sources, current_round)
        if req["status"] == "active":
            canonical = json.dumps(req["value"], sort_keys=True, separators=(",", ":"))
            old = active_by_key.setdefault(req["semantic_key"], canonical)
            if old != canonical:
                raise ValidationError(f"incompatible active values for semantic_key {req['semantic_key']}")
    _validate_supersession_links(ir["requirements"], ids)


def _validate_ir_v2(ir: Mapping[str, Any], *, current_round: int | None,
                    ledger: Any | None) -> None:
    _validate_schema(ir, "intent_ir.schema.json", "Intent IR")
    compiled = ir["compiled_through_round"]
    if current_round is not None and compiled > current_round:
        raise ValidationError("future-round leakage in IR")
    sources = normalize_ledger(ledger) if ledger is not None else None

    clauses: dict[str, Mapping[str, Any]] = {}
    by_round: dict[int, list[Mapping[str, Any]]] = {}
    for clause in ir["clauses"]:
        if clause["id"] in clauses:
            raise ValidationError(f"duplicate clause ID: {clause['id']}")
        clauses[clause["id"]] = clause
        if len(clause["requirement_ids"]) != len(set(clause["requirement_ids"])):
            raise ValidationError(f"duplicate requirement backlink in {clause['id']}")
        by_round.setdefault(clause["source_round"], []).append(clause)
        if clause["source_round"] > compiled:
            raise ValidationError(f"future-round leakage: {clause['id']}")

    if sources is not None:
        for round_no in range(1, compiled + 1):
            if round_no not in sources:
                raise ValidationError(f"source round {round_no} is absent from ledger")
            expected = segment_instruction(sources[round_no], round_no)
            actual = sorted(by_round.get(round_no, []), key=lambda item: item["start"])
            if len(actual) != len(expected):
                raise ValidationError(f"clause coverage mismatch for round {round_no}")
            digest = sha256_text(sources[round_no])
            for got, want in zip(actual, expected, strict=True):
                for key in ("id", "text", "start", "end"):
                    if got[key] != want[key]:
                        raise ValidationError(f"non-verbatim clause partition: {got['id']}")
                if got["instruction_sha256"] != digest:
                    raise ValidationError(f"instruction SHA-256 mismatch for {got['id']}")

    requirements = ir["requirements"]
    ids: set[str] = set()
    active_keys: set[str] = set()
    for req in requirements:
        ident = req["id"]
        if ident in ids:
            raise ValidationError(f"duplicate ID: {ident}")
        ids.add(ident)
        if req["source_round"] > compiled:
            raise ValidationError(f"future-round leakage: {ident}")
        if req["status"] == "active" and req["semantic_key"] in active_keys:
            raise ValidationError(f"multiple active requirements for semantic_key {req['semantic_key']}")
        if req["status"] == "active":
            active_keys.add(req["semantic_key"])
        if req["modality"] != "unknown" and not _has_spec_detail(req["spec"]):
            raise ValidationError(f"incomplete executable spec for {ident}")
        if len(req["source_clause_ids"]) != len(set(req["source_clause_ids"])):
            raise ValidationError(f"duplicate source clause for {ident}")
        if len(req["evidence_clause_ids"]) != len(set(req["evidence_clause_ids"])):
            raise ValidationError(f"duplicate evidence clause for {ident}")
        for clause_id in req["source_clause_ids"]:
            clause = clauses.get(clause_id)
            if clause is None:
                raise ValidationError(f"missing source clause {clause_id} for {ident}")
            if ident not in clause["requirement_ids"]:
                raise ValidationError(f"missing clause backlink for {ident}")
            if clause["source_round"] != req["source_round"]:
                raise ValidationError(f"mixed source rounds for {ident}")
            if clause["instruction_sha256"] != req["instruction_sha256"]:
                raise ValidationError(f"source hash mismatch for {ident}")
        for clause_id in req.get("evidence_clause_ids", []):
            clause = clauses.get(clause_id)
            if clause is None:
                raise ValidationError(f"missing evidence clause {clause_id} for {ident}")
            if ident not in clause["requirement_ids"]:
                raise ValidationError(f"missing evidence backlink for {ident}")
        if not any(clauses[c]["kind"] == "normative" for c in req["source_clause_ids"]):
            raise ValidationError(f"requirement lacks normative source: {ident}")
    for clause in ir["clauses"]:
        for ident in clause["requirement_ids"]:
            if ident not in ids:
                raise ValidationError(f"clause references missing requirement: {ident}")
            req = next(item for item in requirements if item["id"] == ident)
            linked = req["source_clause_ids"] + req.get("evidence_clause_ids", [])
            if clause["id"] not in linked:
                raise ValidationError(f"missing requirement backlink for {clause['id']}")
    _validate_supersession_links(requirements, ids)


def _validate_supersession_links(requirements: list[Mapping[str, Any]], ids: set[str]) -> None:
    for req in requirements:
        if req.get("supersedes") is not None and req["supersedes"] not in ids:
            raise ValidationError(f"missing superseded ID: {req['supersedes']}")
        if req["status"] == "superseded" and req.get("superseded_by") not in ids:
            raise ValidationError(f"missing superseding ID: {req['superseded_by']}")
        if req["status"] == "active" and (req.get("superseded_by") is not None or req.get("superseded_round") is not None):
            raise ValidationError(f"active requirement has supersession tombstone: {req['id']}")


def _validate_v1_source(item: Mapping[str, Any], ledger: dict[int, str],
                        current_round: int | None) -> None:
    round_no = item["source_round"]
    if current_round is not None and round_no > current_round:
        raise ValidationError("source round exceeds current round")
    if round_no not in ledger:
        raise ValidationError(f"source round {round_no} is absent from ledger")
    instruction = ledger[round_no]
    if item["source_quote"] not in instruction:
        raise ValidationError(f"source quote is not verbatim for {item['id']}")
    if item["instruction_sha256"] != sha256_text(instruction):
        raise ValidationError(f"instruction SHA-256 mismatch for {item['id']}")


def validate_delta(delta: Mapping[str, Any], previous_ir: Mapping[str, Any],
                   ledger: Any, current_round: int) -> None:
    version = delta.get("ir_version", 1)
    if version == 1:
        _validate_delta_v1(delta, previous_ir, ledger, current_round)
    elif version == 2:
        _validate_delta_v2(delta, previous_ir, ledger, current_round)
    else:
        raise ValidationError(f"unsupported Intent Delta version: {version}")


def _validate_common(delta: Mapping[str, Any], previous_ir: Mapping[str, Any],
                     ledger: Any, current_round: int) -> dict[int, str]:
    sources = normalize_ledger(ledger)
    if any(r > current_round for r in sources):
        raise ValidationError("future-round leakage in source ledger")
    if current_round not in sources:
        raise ValidationError("current round missing from source ledger")
    if delta["round"] != current_round:
        raise ValidationError("delta round does not equal current round")
    if delta["instruction_sha256"] != sha256_text(sources[current_round]):
        raise ValidationError("delta instruction SHA-256 mismatch")
    validate_ir(previous_ir, current_round=current_round - 1, ledger=sources)
    return sources


def _validate_operations(operations: list[Mapping[str, Any]], previous_ir: Mapping[str, Any],
                         *, v2: bool) -> None:
    existing = {r["id"]: r for r in previous_ir["requirements"]}
    seen = set(existing)
    targeted: set[str] = set()
    for op in operations:
        if op["id"] in seen:
            raise ValidationError(f"duplicate ID: {op['id']}")
        seen.add(op["id"])
        if op["operation"] == "add":
            if op["target_id"] is not None:
                raise ValidationError("add operation target_id must be null")
        else:
            target = op["target_id"]
            if not isinstance(target, str):
                raise ValidationError("replacement operation requires target_id")
            if target not in existing:
                raise ValidationError(f"superseded ID does not exist: {target}")
            if existing[target]["status"] != "active":
                raise ValidationError(f"superseded ID is not active: {target}")
            if target in targeted:
                raise ValidationError(f"ID superseded more than once: {target}")
            if existing[target]["semantic_key"] != op["semantic_key"]:
                raise ValidationError("replacement semantic_key differs from target")
            targeted.add(target)
        if v2:
            if op["operation"] == "mark_unknown" and op["modality"] != "unknown":
                raise ValidationError("mark_unknown requires unknown modality")
            if op["operation"] != "mark_unknown" and op["modality"] == "unknown":
                raise ValidationError("unknown modality requires mark_unknown")
            if op["modality"] != "unknown" and not _has_spec_detail(op["spec"]):
                raise ValidationError(f"incomplete executable spec for {op['id']}")
            if len(op["source_clause_ids"]) != len(set(op["source_clause_ids"])):
                raise ValidationError(f"duplicate source clause for {op['id']}")
        else:
            if op["operation"] == "mark_unknown":
                if op["modality"] != "unknown" or op["value"] is not None:
                    raise ValidationError("mark_unknown requires unknown modality and null value")
            elif op["value"] is None:
                raise ValidationError("only mark_unknown may have a null value")


def _validate_delta_v1(delta: Mapping[str, Any], previous_ir: Mapping[str, Any],
                       ledger: Any, current_round: int) -> None:
    _validate_schema(delta, "intent_delta_v1.schema.json", "Intent Delta")
    sources = _validate_common(delta, previous_ir, ledger, current_round)
    for op in delta["operations"]:
        _validate_v1_source(op, sources, current_round)
    _validate_operations(delta["operations"], previous_ir, v2=False)


def _validate_delta_v2(delta: Mapping[str, Any], previous_ir: Mapping[str, Any],
                       ledger: Any, current_round: int) -> None:
    _validate_schema(delta, "intent_delta.schema.json", "Intent Delta")
    if previous_ir.get("version") != 2:
        raise ValidationError("v2 delta requires v2 previous IR")
    sources = _validate_common(delta, previous_ir, ledger, current_round)
    expected_clauses = segment_instruction(sources[current_round], current_round)
    expected_ids = {item["id"] for item in expected_clauses}
    dispositions = delta["clause_dispositions"]
    disposition_ids = [item["clause_id"] for item in dispositions]
    if len(disposition_ids) != len(set(disposition_ids)):
        raise ValidationError("duplicate clause disposition")
    if set(disposition_ids) != expected_ids:
        raise ValidationError("clause dispositions do not exactly cover current instruction")

    _validate_operations(delta["operations"], previous_ir, v2=True)
    existing_ids = {item["id"] for item in previous_ir["requirements"]}
    operation_ids = {item["id"] for item in delta["operations"]}
    all_ids = existing_ids | operation_ids
    disposition_by_id = {item["clause_id"]: item for item in dispositions}
    for disposition in dispositions:
        if len(disposition["requirement_ids"]) != len(set(disposition["requirement_ids"])):
            raise ValidationError(f"duplicate requirement ID in {disposition['clause_id']}")
        if disposition["kind"] == "normative" and not disposition["requirement_ids"]:
            raise ValidationError(f"normative clause has no requirement: {disposition['clause_id']}")
        for ident in disposition["requirement_ids"]:
            if ident not in all_ids:
                raise ValidationError(f"clause references missing requirement: {ident}")
    for op in delta["operations"]:
        normative = False
        for clause_id in op["source_clause_ids"]:
            if clause_id not in expected_ids:
                raise ValidationError(f"operation references unknown clause: {clause_id}")
            disposition = disposition_by_id[clause_id]
            if op["id"] not in disposition["requirement_ids"]:
                raise ValidationError(f"missing clause backlink for {op['id']}")
            normative = normative or disposition["kind"] == "normative"
        if not normative:
            raise ValidationError(f"operation lacks normative source: {op['id']}")


def _has_spec_detail(spec: Mapping[str, Any]) -> bool:
    """A prose summary alone is not an executable contract."""
    return any(value for key, value in spec.items() if key != "summary")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("delta")
    parser.add_argument("previous_ir")
    parser.add_argument("ledger")
    parser.add_argument("--round", type=int, required=True)
    args = parser.parse_args()
    validate_delta(load_json(args.delta), load_json(args.previous_ir), load_json(args.ledger), args.round)
    print("valid")


if __name__ == "__main__":
    main()
