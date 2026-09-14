import json
import subprocess
import sys
from pathlib import Path

import pytest

from compile_round import build_prompt, compile_round_artifacts, empty_ir
from materialize_task import materialize_task, materialize_task_from_compiled
from render_active_ir import focused_view, render_active_ir, transition_view
from validate_delta import sha256_text
from validate_task_copy import TaskCopyError, validate_task_copy


def spec(summary, value):
    return {
        "summary": summary,
        "interface": [{"key": "feature", "value": value}],
        "input_schema": [], "output_schema": [], "preconditions": [],
        "algorithm": [], "formulas": [], "defaults": [], "ordering": [],
        "formatting": [], "edge_cases": [], "errors": [], "examples": [],
        "integration": [], "invariants": [], "notes": [],
    }


def semantic(prompt):
    payload = json.loads(prompt.split("<compiler-input>\n", 1)[1].split("\n</compiler-input>", 1)[0])
    n = payload["current_round"]
    instruction = payload["current_verbatim_instruction"]
    clause_ids = [item["id"] for item in payload["current_instruction_clauses"]]
    ident, target, kind, value = ("R1", None, "add", "alpha") if n == 1 else ("R2", "R1", "revise", "beta")
    operation = {
        "operation": kind, "id": ident, "target_id": target,
        "semantic_key": "feature.name", "modality": "must",
        "spec": spec(f"Implement {value}", value),
        "source_clause_ids": clause_ids,
    }
    return {
        "ir_version": 2, "round": n, "instruction_sha256": sha256_text(instruction),
        "clause_dispositions": [
            {"clause_id": clause_id, "kind": "normative", "requirement_ids": [ident]}
            for clause_id in clause_ids
        ],
        "operations": [operation],
    }


def make_task(root: Path):
    (root / "steps/round-1").mkdir(parents=True)
    (root / "steps/round-2").mkdir(parents=True)
    (root / "steps/round-1/instruction.md").write_text("Build alpha.\n")
    (root / "steps/round-2/instruction.md").write_text("Change alpha to beta.\n")
    (root / "tests").mkdir()
    (root / "tests/test_hidden.py").write_text("SECRET = True\n")
    (root / "solution.sh").write_text("reference\n")
    (root / "task.json").write_text(json.dumps({"name": "original", "difficulty": "easy"}))


def test_prompt_supplies_hashes_and_lossless_clauses():
    instruction = "Build alpha.\n\nExact output.\n"
    prompt = build_prompt(empty_ir(), instruction, {1: instruction}, 1)
    payload = json.loads(prompt.split("<compiler-input>\n", 1)[1].split("\n</compiler-input>", 1)[0])
    assert payload["current_instruction_sha256"] == sha256_text(instruction)
    assert "".join(item["text"] for item in payload["current_instruction_clauses"]) == instruction


def test_append_materialization_and_validation(tmp_path):
    source, destination, compiled = tmp_path / "source", tmp_path / "copy", tmp_path / "compiled"
    make_task(source)
    ir = materialize_task(source, destination, compiled, new_name="compiled", semantic_compiler=semantic)
    validate_task_copy(source, destination)
    assert ir["version"] == 2 and ir["compiled_through_round"] == 2
    assert "[INTENT CONTRACT V2]" in (destination / "steps/round-2/instruction.md").read_text()
    assert (destination / "tests/test_hidden.py").read_bytes() == (source / "tests/test_hidden.py").read_bytes()
    for number in (1, 2):
        artifact = compiled / f"round-{number:02d}"
        assert {path.name for path in artifact.iterdir()} == {
            "intent_delta.json", "intent_ir.json", "intent_contract.md"
        }


def test_contract_only_materialization_and_validation(tmp_path):
    source, destination, compiled = tmp_path / "source", tmp_path / "copy", tmp_path / "compiled"
    make_task(source)
    materialize_task(source, destination, compiled, semantic_compiler=semantic, instruction_mode="contract-only")
    validate_task_copy(source, destination, instruction_mode="contract-only", compiled_directory=compiled)
    assert (destination / "steps/round-1/instruction.md").read_bytes() == (compiled / "round-01/intent_contract.md").read_bytes()
    assert b"Build alpha.\n[INTENT" not in (destination / "steps/round-1/instruction.md").read_bytes()


def test_compact_contract_omits_duplicate_evidence_but_preserves_semantics(tmp_path):
    source, destination, compiled = tmp_path / "source", tmp_path / "copy", tmp_path / "compiled"
    make_task(source)
    ir = materialize_task(source, destination, compiled, semantic_compiler=semantic,
                          instruction_mode="contract-only", contract_profile="compact")
    contract = (destination / "steps/round-2/instruction.md").read_text()
    validate_task_copy(source, destination, instruction_mode="contract-only", compiled_directory=compiled)
    assert contract.startswith("[INTENT CONTRACT V2 COMPACT]")
    assert '"summary":"Implement beta"' in contract
    assert "clauses: r002-c001" in contract
    assert "Verbatim source clauses:" not in contract
    assert "Change alpha to beta." not in contract
    assert len(contract) < len(render_active_ir(ir))


def test_rematerialize_from_compiled_ir(tmp_path):
    source = tmp_path / "source"
    first_copy, first_compiled = tmp_path / "first-copy", tmp_path / "first-compiled"
    compact_copy, compact_compiled = tmp_path / "compact-copy", tmp_path / "compact-compiled"
    make_task(source)
    expected = materialize_task(source, first_copy, first_compiled, semantic_compiler=semantic,
                                instruction_mode="contract-only")
    actual = materialize_task_from_compiled(
        source, compact_copy, first_compiled, compact_compiled,
        new_name="compact", contract_profile="compact",
    )
    validate_task_copy(source, compact_copy, instruction_mode="contract-only",
                       compiled_directory=compact_compiled)
    assert actual == expected
    assert (compact_compiled / "round-02/intent_ir.json").read_bytes() == \
           (first_compiled / "round-02/intent_ir.json").read_bytes()
    assert (compact_copy / "steps/round-2/instruction.md").read_text().startswith(
        "[INTENT CONTRACT V2 COMPACT]"
    )


def test_focused_contract_details_current_round_and_indexes_history(tmp_path):
    source = tmp_path / "source"
    full_copy, full_compiled = tmp_path / "full-copy", tmp_path / "full-compiled"
    focused_copy, focused_compiled = tmp_path / "focused-copy", tmp_path / "focused-compiled"
    make_task(source)

    def additive_semantic(prompt):
        result = semantic(prompt)
        if result["round"] == 2:
            operation = result["operations"][0]
            operation["operation"] = "add"
            operation["target_id"] = None
            operation["semantic_key"] = "other.setting"
        return result

    expected = materialize_task(
        source, full_copy, full_compiled, semantic_compiler=additive_semantic,
        instruction_mode="contract-only",
    )
    actual = materialize_task_from_compiled(
        source, focused_copy, full_compiled, focused_compiled,
        new_name="focused", contract_profile="focused",
    )
    validate_task_copy(
        source, focused_copy, instruction_mode="contract-only",
        compiled_directory=focused_compiled,
    )
    contract = (focused_copy / "steps/round-2/instruction.md").read_text()
    view = json.loads((focused_compiled / "round-02/intent_view.json").read_text())
    assert actual == expected
    assert (focused_compiled / "round-02/intent_ir.json").read_bytes() == \
           (full_compiled / "round-02/intent_ir.json").read_bytes()
    assert contract.startswith("[INTENT CONTRACT V2 FOCUSED]")
    assert "[CURRENT ROUND EXECUTION SPECIFICATION]" in contract
    assert '"summary":"Implement beta"' in contract
    assert "- MUST `feature.name` — R1: Implement alpha" in contract
    assert view == focused_view(
        expected,
        json.loads((full_compiled / "round-02/intent_delta.json").read_text()),
    )
    assert view["touched_requirement_ids"] == ["R2"]
    assert view["preserved_requirement_ids"] == ["R1"]
    assert view["superseded_requirement_ids"] == []


def test_focused_contract_requires_matching_delta():
    ir = empty_ir()
    with pytest.raises(ValueError, match="requires the current Intent Delta"):
        render_active_ir(ir, profile="focused")
    with pytest.raises(ValueError, match="does not match"):
        render_active_ir(ir, profile="focused", delta={})


def test_transition_contract_uses_prior_state_digest_instead_of_history_text(tmp_path):
    source = tmp_path / "source"
    full_copy, full_compiled = tmp_path / "full-copy", tmp_path / "full-compiled"
    transition_copy = tmp_path / "transition-copy"
    transition_compiled = tmp_path / "transition-compiled"
    make_task(source)

    def additive_semantic(prompt):
        result = semantic(prompt)
        if result["round"] == 1:
            result["operations"][0]["semantic_key"] = "build.go_command"
        if result["round"] == 2:
            operation = result["operations"][0]
            operation["operation"] = "add"
            operation["target_id"] = None
            operation["semantic_key"] = "other.setting"
        return result

    expected = materialize_task(
        source, full_copy, full_compiled, semantic_compiler=additive_semantic,
        instruction_mode="contract-only",
    )
    actual = materialize_task_from_compiled(
        source, transition_copy, full_compiled, transition_compiled,
        new_name="transition", contract_profile="transition",
    )
    validate_task_copy(
        source, transition_copy, instruction_mode="contract-only",
        compiled_directory=transition_compiled,
    )
    contract = (transition_copy / "steps/round-2/instruction.md").read_text()
    delta = json.loads((full_compiled / "round-02/intent_delta.json").read_text())
    view = json.loads((transition_compiled / "round-02/intent_view.json").read_text())
    assert actual == expected
    assert (transition_compiled / "round-02/intent_ir.json").read_bytes() == \
           (full_compiled / "round-02/intent_ir.json").read_bytes()
    assert contract.startswith("[INTENT CONTRACT V2 TRANSITION]")
    assert '## `other.setting`' in contract
    assert '"summary":"Implement beta"' in contract
    assert "[EXECUTION ANCHORS]" in contract
    assert '## `build.go_command`' in contract
    assert '"summary":"Implement alpha"' in contract
    assert "clauses:" not in contract and "source round:" not in contract
    assert "Preserved active requirements: 0" in contract
    assert view == transition_view(expected, delta)
    assert view["execution_anchor_requirement_ids"] == ["R1"]
    assert view["preserved_requirement_ids"] == []
    assert len(view["preserved_state_sha256"]) == 64


def test_transition_contract_renders_only_current_supersession(tmp_path):
    source, destination, compiled = tmp_path / "source", tmp_path / "copy", tmp_path / "compiled"
    make_task(source)
    ir = materialize_task(
        source, destination, compiled, semantic_compiler=semantic,
        instruction_mode="contract-only", contract_profile="transition",
    )
    contract = (destination / "steps/round-2/instruction.md").read_text()
    view = json.loads((compiled / "round-02/intent_view.json").read_text())
    validate_task_copy(
        source, destination, instruction_mode="contract-only", compiled_directory=compiled,
    )
    assert ir["compiled_through_round"] == 2
    assert view["current_superseded_requirement_ids"] == ["R1"]
    assert "- `feature.name`: replace prior behavior" in contract


def test_transition_contract_requires_matching_delta():
    ir = empty_ir()
    with pytest.raises(ValueError, match="requires the current Intent Delta"):
        render_active_ir(ir, profile="transition")
    with pytest.raises(ValueError, match="does not match"):
        render_active_ir(ir, profile="transition", delta={})


def test_validator_rejects_test_change(tmp_path):
    source, destination, compiled = tmp_path / "source", tmp_path / "copy", tmp_path / "compiled"
    make_task(source)
    materialize_task(source, destination, compiled, semantic_compiler=semantic)
    (destination / "tests/test_hidden.py").write_text("tampered\n")
    with pytest.raises(TaskCopyError, match="unauthorized"):
        validate_task_copy(source, destination)


def test_validator_rejects_replaced_instruction(tmp_path):
    source, destination, compiled = tmp_path / "source", tmp_path / "copy", tmp_path / "compiled"
    make_task(source)
    materialize_task(source, destination, compiled, semantic_compiler=semantic)
    instruction = destination / "steps/round-1/instruction.md"
    instruction.write_text(instruction.read_text().replace("Build alpha.", "Build gamma."))
    with pytest.raises(TaskCopyError, match="preserve original bytes"):
        validate_task_copy(source, destination)


def test_validator_rejects_future_round_contract(tmp_path):
    source, destination, compiled = tmp_path / "source", tmp_path / "copy", tmp_path / "compiled"
    make_task(source)
    materialize_task(source, destination, compiled, semantic_compiler=semantic)
    instruction = destination / "steps/round-1/instruction.md"
    instruction.write_text(instruction.read_text().replace("source round: 1", "source round: 9"))
    with pytest.raises(TaskCopyError, match="future-round"):
        validate_task_copy(source, destination)


def test_validator_cli_prints_pass(tmp_path):
    source, destination, compiled = tmp_path / "source", tmp_path / "copy", tmp_path / "compiled"
    make_task(source)
    materialize_task(source, destination, compiled, semantic_compiler=semantic)
    result = subprocess.run([sys.executable, "-m", "validate_task_copy", str(source), str(destination)],
                            text=True, capture_output=True, check=False)
    assert result.returncode == 0 and result.stdout == "PASS\n"


def test_materializer_cleans_outputs_on_failure(tmp_path):
    source, destination, compiled = tmp_path / "source", tmp_path / "copy", tmp_path / "compiled"
    make_task(source)

    def fail_on_second(prompt):
        payload = json.loads(prompt.split("<compiler-input>\n", 1)[1].split("\n</compiler-input>", 1)[0])
        if payload["current_round"] == 2:
            raise RuntimeError("semantic failure")
        return semantic(prompt)

    with pytest.raises(RuntimeError, match="semantic failure"):
        materialize_task(source, destination, compiled, semantic_compiler=fail_on_second)
    assert not destination.exists() and not compiled.exists()


def test_round_compiler_retries_deterministic_validation_failure():
    calls = []

    def inconsistent_then_valid(prompt):
        calls.append(prompt)
        result = semantic(prompt)
        if len(calls) == 1:
            result["clause_dispositions"][0]["requirement_ids"] = ["OTHER"]
        return result

    instruction = "Build alpha.\n"
    _, ir = compile_round_artifacts(
        empty_ir(), instruction, {1: instruction}, 1, inconsistent_then_valid
    )
    assert ir["compiled_through_round"] == 1
    assert len(calls) == 2
    assert "<validation-feedback>" in calls[1]


def test_round_compiler_does_not_rewrite_domain_semantics():
    def semantic_with_legacy_surface(prompt):
        result = semantic(prompt)
        result["operations"][0]["spec"]["output_schema"] = [
            {
                "key": "legacy_name",
                "value": "Replacement-128 value stored under the legacy name.",
            }
        ]
        result["operations"][0]["spec"]["notes"] = [
            "The source does not specify an interface rename."
        ]
        return result

    instruction = "Build alpha.\n"
    delta, ir = compile_round_artifacts(
        empty_ir(), instruction, {1: instruction}, 1, semantic_with_legacy_surface
    )
    expected = [{
        "key": "legacy_name",
        "value": "Replacement-128 value stored under the legacy name.",
    }]
    assert delta["operations"][0]["spec"]["output_schema"] == expected
    assert ir["requirements"][0]["spec"]["output_schema"] == expected
