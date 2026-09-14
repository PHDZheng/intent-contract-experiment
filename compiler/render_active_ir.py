"""Stable human-readable rendering of v1 and replacement-grade v2 contracts."""
from __future__ import annotations

import argparse
import hashlib
import json
from typing import Any, Mapping

from validate_delta import load_json, validate_ir


def _v1_line(req: Mapping[str, Any]) -> str:
    value = json.dumps(req["value"], ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    provenance = f"round {req['source_round']}, sha256 {req['instruction_sha256']}"
    relation = f", supersedes {req['supersedes']}" if "supersedes" in req else ""
    statement = " ".join(req["statement"].split())
    return f"- [{req['id']}] **{req['modality'].upper()}** `{req['semantic_key']}` = `{value}` — {statement} ({provenance}{relation})"


def render_active_ir(ir: Mapping[str, Any], *, profile: str = "full",
                     delta: Mapping[str, Any] | None = None) -> str:
    validate_ir(ir)
    if profile not in {"full", "compact", "focused", "transition"}:
        raise ValueError("profile must be 'full', 'compact', 'focused', or 'transition'")
    if ir["version"] == 1:
        if profile != "full":
            raise ValueError("compact, focused, and transition rendering require Intent IR v2")
        return _render_v1(ir)
    if profile == "focused":
        if delta is None:
            raise ValueError("focused rendering requires the current Intent Delta")
        return _render_v2_focused(ir, delta)
    if profile == "transition":
        if delta is None:
            raise ValueError("transition rendering requires the current Intent Delta")
        return _render_v2_transition(ir, delta)
    if profile == "compact":
        return _render_v2_compact(ir)
    return _render_v2(ir)


def _render_v1(ir: Mapping[str, Any]) -> str:
    active = sorted((r for r in ir["requirements"] if r["status"] == "active"), key=lambda r: r["id"])
    old = sorted((r for r in ir["requirements"] if r["status"] == "superseded"), key=lambda r: r["id"])
    lines = ["[CURRENT ACTIVE INTENT]", ""]
    lines.extend((_v1_line(r) for r in active) if active else ["_None._"])
    lines.extend(["", "[SUPERSEDED INTENT]", ""])
    lines.extend((_v1_line(r) + f" → {r['superseded_by']} (round {r['superseded_round']})" for r in old)
                 if old else ["_None._"])
    lines.extend(["", "[EXECUTION]", "", "Implement the current request while preserving all active intent.",
                  "Do not restore superseded behavior."])
    return "\n".join(lines) + "\n"


def _render_v2(ir: Mapping[str, Any]) -> str:
    active = sorted((r for r in ir["requirements"] if r["status"] == "active"),
                    key=lambda r: (r["semantic_key"], r["id"]))
    old = sorted((r for r in ir["requirements"] if r["status"] == "superseded"), key=lambda r: r["id"])
    clauses = {item["id"]: item for item in ir["clauses"]}
    normative = sum(item["kind"] == "normative" for item in ir["clauses"])
    mapped = sum(item["kind"] == "normative" and bool(item["requirement_ids"]) for item in ir["clauses"])
    lines = [
        "[INTENT CONTRACT V2]", "",
        f"Compiled through round: {ir['compiled_through_round']}",
        f"Normative clause coverage: {mapped}/{normative}", "",
        "[CURRENT ACTIVE SPECIFICATION]", "",
    ]
    if not active:
        lines.append("_None._")
    for req in active:
        relation = f"; supersedes `{req['supersedes']}`" if "supersedes" in req else ""
        lines.extend([
            f"## `{req['semantic_key']}` — {req['id']}", "",
            f"Modality: **{req['modality'].upper()}**; source round: {req['source_round']}; "
            f"SHA-256: `{req['instruction_sha256']}`{relation}", "",
            f"Summary: {req['spec']['summary']}", "",
        ])
        details = {key: value for key, value in req["spec"].items() if key != "summary"}
        lines.extend(["Specification:", "", "```json",
                      json.dumps(details, ensure_ascii=False, indent=2, sort_keys=True), "```", "",
                      "Verbatim source clauses:", ""])
        for clause_id in req["source_clause_ids"] + req.get("evidence_clause_ids", []):
            clause = clauses[clause_id]
            lines.extend([f"- `{clause_id}` ({clause['kind']}):", "", "```text",
                          clause["text"].rstrip("\n"), "```", ""])
    lines.extend(["[SUPERSEDED TOMBSTONES]", ""])
    if old:
        for req in old:
            lines.append(
                f"- `{req['id']}` `{req['semantic_key']}` → `{req['superseded_by']}` "
                f"(round {req['superseded_round']})"
            )
    else:
        lines.append("_None._")
    lines.extend([
        "", "[EXECUTION]", "",
        "Implement this contract as the complete specification for the current task state.",
        "Preserve every active specification and exact normative source clause.",
        "Do not restore behavior listed in superseded tombstones.",
        "Do not consult an earlier natural-language instruction to fill missing details.",
    ])
    return "\n".join(lines) + "\n"


def _nonempty_spec(spec: Mapping[str, Any]) -> dict[str, Any]:
    """Retain every semantic value while removing schema-default empty fields."""
    return {key: value for key, value in spec.items() if value not in ([], "", None)}


def focused_view(ir: Mapping[str, Any], delta: Mapping[str, Any]) -> dict[str, Any]:
    """Select a deterministic execution slice while indexing every active requirement."""
    validate_ir(ir)
    if ir["version"] != 2:
        raise ValueError("focused view requires Intent IR v2")
    round_no = ir["compiled_through_round"]
    if delta.get("ir_version") != 2 or delta.get("round") != round_no:
        raise ValueError("focused view delta does not match the compiled IR round")

    active = {item["id"]: item for item in ir["requirements"] if item["status"] == "active"}
    operation_ids = {item["id"] for item in delta.get("operations", [])}
    disposition_ids = {
        ident
        for item in delta.get("clause_dispositions", [])
        for ident in item.get("requirement_ids", [])
    }
    touched_ids = (operation_ids | disposition_ids) & set(active)
    if not touched_ids:
        raise ValueError("focused view has no active requirement touched by the current delta")
    missing_operations = operation_ids - set(active)
    if missing_operations:
        raise ValueError(f"focused view operation is not active: {sorted(missing_operations)}")

    touched = [active[ident] for ident in sorted(touched_ids)]
    focus_text = json.dumps(
        [{"semantic_key": item["semantic_key"], "spec": _nonempty_spec(item["spec"])}
         for item in touched],
        ensure_ascii=False,
        sort_keys=True,
    ).lower()
    dependency_ids: set[str] = set()
    for ident, item in active.items():
        if ident in touched_ids:
            continue
        key = item["semantic_key"].lower()
        phrase = key.replace("_", " ").replace(".", " ").replace("-", " ")
        explicitly_referenced = ident.lower() in focus_text or key in focus_text or phrase in focus_text
        if explicitly_referenced:
            dependency_ids.add(ident)

    detailed_ids = touched_ids | dependency_ids
    return {
        "version": 1,
        "compiled_through_round": round_no,
        "touched_requirement_ids": sorted(touched_ids),
        "dependency_requirement_ids": sorted(dependency_ids),
        "preserved_requirement_ids": sorted(set(active) - detailed_ids),
        "superseded_requirement_ids": sorted(
            item["id"] for item in ir["requirements"] if item["status"] == "superseded"
        ),
    }


def transition_view(ir: Mapping[str, Any], delta: Mapping[str, Any]) -> dict[str, Any]:
    """Describe a state transition while retaining an auditable prior-state digest."""
    view = focused_view(ir, delta)
    round_no = ir["compiled_through_round"]
    by_id = {item["id"]: item for item in ir["requirements"]}
    detailed_ids = set(view["touched_requirement_ids"]) | set(view["dependency_requirement_ids"])
    execution_anchor_ids = sorted(
        ident for ident, item in by_id.items()
        if item["status"] == "active"
        and item["semantic_key"].startswith(("build.", "execution."))
        and ident not in detailed_ids
    )
    preserved_ids = sorted(set(view["preserved_requirement_ids"]) - set(execution_anchor_ids))
    preserved = [by_id[ident] for ident in preserved_ids]
    canonical = json.dumps(preserved, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    current_superseded = sorted(
        item["id"] for item in ir["requirements"]
        if item["status"] == "superseded" and item["superseded_round"] == round_no
    )
    return {
        **view,
        "profile": "transition",
        "execution_anchor_requirement_ids": execution_anchor_ids,
        "preserved_requirement_ids": preserved_ids,
        "preserved_state_sha256": hashlib.sha256(canonical.encode("utf-8")).hexdigest(),
        "current_superseded_requirement_ids": current_superseded,
    }


def _compact_requirement_lines(req: Mapping[str, Any]) -> list[str]:
    clause_ids = list(dict.fromkeys(req["source_clause_ids"] + req.get("evidence_clause_ids", [])))
    metadata = [f"{req['modality'].upper()}; source round: {req['source_round']}"]
    if req.get("supersedes") is not None:
        metadata.append(f"supersedes: {req['supersedes']}")
    metadata.append("clauses: " + ",".join(clause_ids))
    return [
        f"## `{req['semantic_key']}` — {req['id']}",
        "; ".join(metadata),
        json.dumps(_nonempty_spec(req["spec"]), ensure_ascii=False, sort_keys=True,
                   separators=(",", ":")),
        "",
    ]


def _transition_requirement_lines(req: Mapping[str, Any]) -> list[str]:
    """Render executable semantics; provenance remains in the audit sidecar."""
    return [
        f"## `{req['semantic_key']}`",
        json.dumps(_nonempty_spec(req["spec"]), ensure_ascii=False, sort_keys=True,
                   separators=(",", ":")),
        "",
    ]


def _render_v2_compact(ir: Mapping[str, Any]) -> str:
    """Render active semantics without duplicating verbatim evidence in the prompt."""
    active = sorted((r for r in ir["requirements"] if r["status"] == "active"),
                    key=lambda r: (r["semantic_key"], r["id"]))
    old = sorted((r for r in ir["requirements"] if r["status"] == "superseded"), key=lambda r: r["id"])
    normative = sum(item["kind"] == "normative" for item in ir["clauses"])
    mapped = sum(item["kind"] == "normative" and bool(item["requirement_ids"]) for item in ir["clauses"])
    lines = [
        "[INTENT CONTRACT V2 COMPACT]", "",
        f"Compiled through round: {ir['compiled_through_round']}",
        f"Normative clause coverage: {mapped}/{normative}",
        "Representation: complete active normalized semantics; evidence text is retained once in Intent IR.", "",
        "[CURRENT ACTIVE SPECIFICATION]", "",
    ]
    if not active:
        lines.append("_None._")
    for req in active:
        lines.extend(_compact_requirement_lines(req))
    lines.extend(["[SUPERSEDED TOMBSTONES]", ""])
    if old:
        for req in old:
            lines.append(
                f"- {req['id']} `{req['semantic_key']}` -> {req['superseded_by']} "
                f"(round {req['superseded_round']})"
            )
    else:
        lines.append("_None._")
    lines.extend([
        "", "[EXECUTION]", "",
        "Implement this compact contract as the complete specification for the current task state.",
        "Every non-empty normalized field above is normative; omitted fields are empty, not unknown.",
        "Clause IDs provide provenance without repeating source text in the execution prompt.",
        "Do not restore behavior listed in superseded tombstones.",
        "Do not consult an earlier natural-language instruction to fill missing details.",
    ])
    return "\n".join(lines) + "\n"


def _render_v2_focused(ir: Mapping[str, Any], delta: Mapping[str, Any]) -> str:
    """Render current work in full and unchanged intent as a preservation index."""
    view = focused_view(ir, delta)
    by_id = {item["id"]: item for item in ir["requirements"]}
    touched = [by_id[ident] for ident in view["touched_requirement_ids"]]
    dependencies = [by_id[ident] for ident in view["dependency_requirement_ids"]]
    preserved = sorted((by_id[ident] for ident in view["preserved_requirement_ids"]),
                       key=lambda item: (item["semantic_key"], item["id"]))
    old = sorted((by_id[ident] for ident in view["superseded_requirement_ids"]),
                 key=lambda item: item["id"])
    normative = sum(item["kind"] == "normative" for item in ir["clauses"])
    mapped = sum(item["kind"] == "normative" and bool(item["requirement_ids"])
                 for item in ir["clauses"])
    lines = [
        "[INTENT CONTRACT V2 FOCUSED]", "",
        f"Compiled through round: {ir['compiled_through_round']}",
        f"Normative clause coverage: {mapped}/{normative}",
        f"Execution slice: {len(touched)} touched + {len(dependencies)} dependencies; "
        f"preservation index: {len(preserved)} unchanged active requirements.",
        "Authority: complete Intent IR is retained in the compiler artifact; this view is derived only from it.", "",
        "[CURRENT ROUND EXECUTION SPECIFICATION]", "",
    ]
    for req in touched:
        lines.extend(_compact_requirement_lines(req))
    lines.extend(["[RELEVANT DEPENDENCY SPECIFICATION]", ""])
    if dependencies:
        for req in dependencies:
            lines.extend(_compact_requirement_lines(req))
    else:
        lines.append("_None._")
    lines.extend(["", "[ACTIVE PRESERVATION INDEX]", ""])
    if preserved:
        for req in preserved:
            summary = " ".join(req["spec"]["summary"].split())
            lines.append(
                f"- {req['modality'].upper()} `{req['semantic_key']}` — {req['id']}: {summary}"
            )
    else:
        lines.append("_None._")
    lines.extend(["", "[SUPERSEDED TOMBSTONES]", ""])
    if old:
        for req in old:
            lines.append(
                f"- {req['id']} `{req['semantic_key']}` -> {req['superseded_by']} "
                f"(round {req['superseded_round']})"
            )
    else:
        lines.append("_None._")
    lines.extend([
        "", "[EXECUTION]", "",
        "Implement the current-round specification and its detailed dependencies.",
        "Preserve every behavior named in the active preservation index; unchanged indexed behavior remains normative.",
        "Do not restore behavior listed in superseded tombstones.",
        "This focused contract is the complete task instruction; do not consult an earlier natural-language instruction.",
    ])
    return "\n".join(lines) + "\n"


def _render_v2_transition(ir: Mapping[str, Any], delta: Mapping[str, Any]) -> str:
    """Render only the executable transition over the persistent prior code state."""
    view = transition_view(ir, delta)
    by_id = {item["id"]: item for item in ir["requirements"]}
    touched = [by_id[ident] for ident in view["touched_requirement_ids"]]
    dependencies = [by_id[ident] for ident in view["dependency_requirement_ids"]]
    execution_anchors = [by_id[ident] for ident in view["execution_anchor_requirement_ids"]]
    current_old = [by_id[ident] for ident in view["current_superseded_requirement_ids"]]
    normative = sum(item["kind"] == "normative" for item in ir["clauses"])
    mapped = sum(item["kind"] == "normative" and bool(item["requirement_ids"])
                 for item in ir["clauses"])
    lines = [
        "[INTENT CONTRACT V2 TRANSITION]", "",
        f"Compiled through round: {ir['compiled_through_round']}",
        f"Normative clause coverage: {mapped}/{normative}",
        "All rendered requirements are MUST requirements.",
        f"Transition slice: {len(touched)} touched + {len(dependencies)} explicit dependencies + "
        f"{len(execution_anchors)} execution anchors.",
        "Provenance and complete state are retained in the compiler audit artifacts, not repeated here.", "",
        "[CURRENT TRANSITION SPECIFICATION]", "",
    ]
    for req in touched:
        lines.extend(_transition_requirement_lines(req))
    lines.extend(["[EXPLICIT DEPENDENCIES]", ""])
    if dependencies:
        for req in dependencies:
            lines.extend(_transition_requirement_lines(req))
    else:
        lines.append("_None._")
    lines.extend(["", "[EXECUTION ANCHORS]", ""])
    if execution_anchors:
        for req in execution_anchors:
            lines.extend(_transition_requirement_lines(req))
    else:
        lines.append("_None._")
    lines.extend(["", "[PRIOR STATE PRESERVATION]", ""])
    lines.extend([
        f"Preserved active requirements: {len(view['preserved_requirement_ids'])}",
        f"Preserved-state SHA-256: {view['preserved_state_sha256']}",
        "All behavior already implemented in the persistent project remains normative unless the current transition explicitly supersedes it.",
        "Do not regress, remove, or reinterpret unaffected behavior.",
        "Use the existing implementation and regression tests as the executable prior state.",
        "",
        "[CURRENT SUPERSESSIONS]", "",
    ])
    if current_old:
        for req in current_old:
            replacement = by_id[req["superseded_by"]]
            lines.append(f"- `{req['semantic_key']}`: replace prior behavior with the current specification above.")
            if replacement["semantic_key"] != req["semantic_key"]:
                raise ValueError("transition supersession semantic key mismatch")
    else:
        lines.append("_None._")
    lines.extend([
        "", "[EXECUTION]", "",
        "Implement this state transition in the existing project.",
        "Preserve the prior state except where this contract explicitly supersedes it.",
        "Run focused checks for the changed behavior, then the complete regression suite.",
        "This transition contract is the complete task instruction; do not consult an earlier natural-language instruction.",
    ])
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("ir")
    parser.add_argument("--profile", choices=("full", "compact", "focused", "transition"), default="full")
    parser.add_argument("--delta", help="current Intent Delta; required by focused and transition profiles")
    args = parser.parse_args()
    if args.profile in {"focused", "transition"} and not args.delta:
        parser.error(f"--profile {args.profile} requires --delta")
    delta = load_json(args.delta) if args.delta else None
    print(render_active_ir(load_json(args.ir), profile=args.profile, delta=delta), end="")


if __name__ == "__main__":
    main()
