"""Losslessly split an instruction into stable Markdown clause blocks."""
from __future__ import annotations

from typing import Any


def segment_instruction(instruction: str, round_no: int) -> list[dict[str, Any]]:
    """Partition instruction exactly while keeping fenced blocks intact."""
    if not instruction:
        raise ValueError("instruction must not be empty")
    clauses: list[dict[str, Any]] = []
    start = 0
    cursor = 0
    fenced = False
    for line in instruction.splitlines(keepends=True):
        if line.lstrip().startswith("```"):
            fenced = not fenced
        cursor += len(line)
        if not fenced and not line.strip():
            clauses.append(_clause(round_no, len(clauses) + 1, start, cursor, instruction[start:cursor]))
            start = cursor
    if start < len(instruction):
        clauses.append(_clause(round_no, len(clauses) + 1, start, len(instruction), instruction[start:]))
    if "".join(item["text"] for item in clauses) != instruction:
        raise AssertionError("instruction segmentation is not lossless")
    return clauses


def _clause(round_no: int, index: int, start: int, end: int, text: str) -> dict[str, Any]:
    return {"id": f"r{round_no:03d}-c{index:03d}", "text": text, "start": start, "end": end}
