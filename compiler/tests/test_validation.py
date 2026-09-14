import copy

import pytest

from compile_round import empty_ir
from merge_ir import merge_ir
from validate_delta import ValidationError, sha256_text, validate_delta, validate_ir


INSTRUCTION = "Add JSON output.\n"
CLAUSE = "r001-c001"


def spec(summary="Output JSON", **details):
    result = {
        "summary": summary, "interface": [], "input_schema": [], "output_schema": [],
        "preconditions": [], "algorithm": [], "formulas": [], "defaults": [],
        "ordering": [], "formatting": [], "edge_cases": [], "errors": [],
        "examples": [], "integration": [], "invariants": [], "notes": [],
    }
    result.update(details)
    return result


def operation(**changes):
    result = {
        "operation": "add", "id": "REQ.output", "target_id": None,
        "semantic_key": "output.format", "modality": "must",
        "spec": spec(output_schema=[{"key": "format", "value": "json"}]),
        "source_clause_ids": [CLAUSE],
    }
    result.update(changes)
    return result


def delta(op=None, **changes):
    result = {
        "ir_version": 2, "round": 1, "instruction_sha256": sha256_text(INSTRUCTION),
        "clause_dispositions": [
            {"clause_id": CLAUSE, "kind": "normative", "requirement_ids": ["REQ.output"]}
        ],
        "operations": [op or operation()],
    }
    result.update(changes)
    return result


def test_valid_v2_delta_and_ir():
    d = delta()
    validate_delta(d, empty_ir(), {1: INSTRUCTION}, 1)
    ir = merge_ir(empty_ir(), d, {1: INSTRUCTION}, 1)
    validate_ir(ir, current_round=1, ledger={1: INSTRUCTION})
    assert "".join(item["text"] for item in ir["clauses"]) == INSTRUCTION


def test_clause_dispositions_must_exactly_cover_instruction():
    d = delta()
    d["clause_dispositions"] = []
    with pytest.raises(ValidationError, match="exactly cover"):
        validate_delta(d, empty_ir(), {1: INSTRUCTION}, 1)


def test_operation_requires_reciprocal_normative_clause():
    d = delta()
    d["clause_dispositions"][0]["requirement_ids"] = ["OTHER"]
    with pytest.raises(ValidationError, match="missing requirement"):
        validate_delta(d, empty_ir(), {1: INSTRUCTION}, 1)


def test_summary_only_spec_is_rejected():
    with pytest.raises(ValidationError, match="incomplete executable spec"):
        validate_delta(delta(op=operation(spec=spec("too short"))), empty_ir(), {1: INSTRUCTION}, 1)


def test_future_ledger_rejected():
    with pytest.raises(ValidationError, match="future-round"):
        validate_delta(delta(), empty_ir(), {1: INSTRUCTION, 2: "secret"}, 1)


def test_duplicate_id_rejected():
    d = delta()
    d["operations"].append(copy.deepcopy(d["operations"][0]))
    with pytest.raises(ValidationError, match="duplicate ID"):
        validate_delta(d, empty_ir(), {1: INSTRUCTION}, 1)


def test_legacy_v1_ir_remains_readable():
    legacy = {"version": 1, "compiled_through_round": 0, "requirements": []}
    validate_ir(legacy, current_round=0, ledger={})
