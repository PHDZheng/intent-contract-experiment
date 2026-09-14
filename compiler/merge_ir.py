"""Pure deterministic application of a validated Intent Delta."""
from __future__ import annotations

import argparse
import copy
import json
from typing import Any, Mapping

from clause_segments import segment_instruction
from validate_delta import load_json, normalize_ledger, validate_delta, validate_ir


def merge_ir(previous_ir: Mapping[str, Any], delta: Mapping[str, Any],
             ledger: Any, current_round: int) -> dict[str, Any]:
    validate_delta(delta, previous_ir, ledger, current_round)
    result = copy.deepcopy(dict(previous_ir))
    if result["version"] == 2:
        _append_v2_clauses(result, delta, ledger, current_round)
    by_id = {r["id"]: r for r in result["requirements"]}
    for op in delta["operations"]:
        kind = op["operation"]
        if kind != "add":
            target = by_id[op["target_id"]]
            target["status"] = "superseded"
            target["superseded_by"] = op["id"]
            target["superseded_round"] = current_round
        req = {k: copy.deepcopy(v) for k, v in op.items() if k not in {"operation", "target_id"}}
        if result["version"] == 2:
            sources = normalize_ledger(ledger)
            req["source_round"] = current_round
            req["instruction_sha256"] = delta["instruction_sha256"]
            mapped_clauses = [
                item["clause_id"] for item in delta["clause_dispositions"]
                if op["id"] in item["requirement_ids"]
            ]
            req["evidence_clause_ids"] = [
                clause_id for clause_id in mapped_clauses
                if clause_id not in req["source_clause_ids"]
            ]
        req["introduced_by"] = kind
        req["status"] = "active"
        req["supersedes"] = op["target_id"] if kind != "add" else None
        req["superseded_by"] = None
        req["superseded_round"] = None
        result["requirements"].append(req)
        by_id[req["id"]] = req
    result["compiled_through_round"] = current_round
    # This also proves no prior active item disappeared: the merge only mutates status
    # for explicitly targeted IDs and otherwise deep-copies the complete prior IR.
    validate_ir(result, current_round=current_round, ledger=ledger)
    return result


def _append_v2_clauses(result: dict[str, Any], delta: Mapping[str, Any],
                       ledger: Any, current_round: int) -> None:
    instruction = normalize_ledger(ledger)[current_round]
    dispositions = {item["clause_id"]: item for item in delta["clause_dispositions"]}
    existing = {item["id"]: item for item in result["requirements"]}
    for segment in segment_instruction(instruction, current_round):
        disposition = dispositions[segment["id"]]
        result["clauses"].append({
            **segment,
            "kind": disposition["kind"],
            "source_round": current_round,
            "instruction_sha256": delta["instruction_sha256"],
            "requirement_ids": copy.deepcopy(disposition["requirement_ids"]),
        })
        for ident in disposition["requirement_ids"]:
            if ident in existing:
                evidence = existing[ident].setdefault("evidence_clause_ids", [])
                if segment["id"] not in evidence:
                    evidence.append(segment["id"])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("previous_ir")
    parser.add_argument("delta")
    parser.add_argument("ledger")
    parser.add_argument("--round", type=int, required=True)
    parser.add_argument("-o", "--output")
    args = parser.parse_args()
    result = merge_ir(load_json(args.previous_ir), load_json(args.delta), load_json(args.ledger), args.round)
    text = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(text)
    else:
        print(text, end="")


if __name__ == "__main__":
    main()
