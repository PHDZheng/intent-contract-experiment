import pytest

from compile_round import empty_ir
from merge_ir import merge_ir
from validate_delta import ValidationError, sha256_text


def spec(summary, value):
    return {
        "summary": summary, "interface": [], "input_schema": [],
        "output_schema": [{"key": "format", "value": value}],
        "preconditions": [], "algorithm": [], "formulas": [], "defaults": [],
        "ordering": [], "formatting": [], "edge_cases": [], "errors": [],
        "examples": [], "integration": [], "invariants": [], "notes": [],
    }


def op(kind, ident, value, clause_id, target=None):
    return {
        "operation": kind, "id": ident, "target_id": target,
        "semantic_key": "output.format", "modality": "must",
        "spec": spec(f"Use {value}", value.lower()),
        "source_clause_ids": [clause_id],
    }


def apply(previous, operations, instruction, round_no, ledger):
    clause_id = f"r{round_no:03d}-c001"
    delta = {
        "ir_version": 2, "round": round_no,
        "instruction_sha256": sha256_text(instruction),
        "clause_dispositions": [{
            "clause_id": clause_id, "kind": "normative",
            "requirement_ids": [item["id"] for item in operations],
        }],
        "operations": operations,
    }
    return merge_ir(previous, delta, ledger, round_no)


def test_revise_explicitly_supersedes_and_preserves_history():
    first_text = "Use JSON."
    ir = apply(empty_ir(), [op("add", "R1", "JSON", "r001-c001")], first_text, 1, {1: first_text})
    second_text = "Use YAML instead."
    ir = apply(ir, [op("revise", "R2", "YAML", "r002-c001", "R1")], second_text, 2,
               {1: first_text, 2: second_text})
    assert [(r["id"], r["status"]) for r in ir["requirements"]] == [("R1", "superseded"), ("R2", "active")]
    assert ir["requirements"][0]["superseded_by"] == "R2"
    assert ir["requirements"][1]["supersedes"] == "R1"


def test_missing_target_rejected():
    text = "Use YAML instead."
    with pytest.raises(ValidationError, match="does not exist"):
        apply(empty_ir(), [op("supersede", "R2", "YAML", "r001-c001", "R1")], text, 1, {1: text})


def test_duplicate_active_semantic_key_rejected_even_for_equal_specs():
    text = "Use JSON."
    operations = [op("add", "R1", "JSON", "r001-c001"), op("add", "R2", "JSON", "r001-c001")]
    with pytest.raises(ValidationError, match="multiple active requirements"):
        apply(empty_ir(), operations, text, 1, {1: text})


def test_reaffirmation_clause_can_map_existing_requirement_without_operation():
    first = "Use JSON."
    ir = apply(empty_ir(), [op("add", "R1", "JSON", "r001-c001")], first, 1, {1: first})
    second = "Keep JSON unchanged."
    delta = {
        "ir_version": 2, "round": 2, "instruction_sha256": sha256_text(second),
        "clause_dispositions": [{
            "clause_id": "r002-c001", "kind": "normative", "requirement_ids": ["R1"]
        }],
        "operations": [],
    }
    ir = merge_ir(ir, delta, {1: first, 2: second}, 2)
    assert ir["requirements"][0]["evidence_clause_ids"] == ["r002-c001"]


def test_new_requirement_records_additional_mapped_clause_as_evidence():
    text = "Use JSON.\n\nFor example, emit an object."
    operation = op("add", "R1", "JSON", "r001-c001")
    delta = {
        "ir_version": 2, "round": 1, "instruction_sha256": sha256_text(text),
        "clause_dispositions": [
            {"clause_id": "r001-c001", "kind": "normative", "requirement_ids": ["R1"]},
            {"clause_id": "r001-c002", "kind": "example", "requirement_ids": ["R1"]},
        ],
        "operations": [operation],
    }
    ir = merge_ir(empty_ir(), delta, {1: text}, 1)
    assert ir["requirements"][0]["evidence_clause_ids"] == ["r001-c002"]
