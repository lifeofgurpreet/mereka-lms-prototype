#!/usr/bin/env python3
"""Verify that proof-like docs do not make temporally false claims."""

from __future__ import annotations

import re
from datetime import date
from pathlib import Path


DATE_RE = re.compile(r"\b(20\d{2}-\d{2}-\d{2})\b")
CLASS_RE = re.compile(r"\*\*Document class\*\*:\s*([a-z-]+)", re.IGNORECASE)
META_RE = re.compile(r"Last (verified|updated)(?: \(UTC\))?: (\d{4}-\d{2}-\d{2})", re.IGNORECASE)

ALLOWED_FUTURE_HINTS = (
    "template",
    "no earlier than",
    "do not publish before",
    "planned",
    "next check",
)

PROOF_HINTS = ("done", "published", "generated", "verified", "closure", "scorecard")


def doc_class(lines: list[str], path: Path) -> str:
    head = "\n".join(lines[:12])
    match = CLASS_RE.search(head)
    if match:
        return match.group(1).lower()
    if "template" in path.name:
        return "template"
    if "tracker" in path.name.lower():
        return "tracker"
    if "scorecard" in path.name.lower():
        return "evidence"
    if "generated" in str(path):
        return "generated"
    if "archive" in str(path):
        return "historical"
    return "unknown"


def metadata_date(lines: list[str]) -> date | None:
    head = "\n".join(lines[:8])
    match = META_RE.search(head)
    if not match:
        return None
    return date.fromisoformat(match.group(2))


def main() -> None:
    today = date.today()
    errors: list[str] = []
    for path in sorted(Path("docs").rglob("*.md")):
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
        kind = doc_class(lines, path)
        meta_date = metadata_date(lines)
        if meta_date and meta_date > today:
            errors.append(f"{path}: metadata date {meta_date} is in the future for class {kind}")
        if not meta_date or kind not in {"tracker", "evidence", "generated"}:
            continue
        for idx, line in enumerate(lines, start=1):
            lowered = line.lower()
            if any(hint in lowered for hint in ALLOWED_FUTURE_HINTS):
                continue
            if not any(hint in lowered for hint in PROOF_HINTS):
                continue
            for token in DATE_RE.findall(line):
                found = date.fromisoformat(token)
                if found > meta_date:
                    errors.append(
                        f"{path}:{idx}: proof-like line references later date {found} than metadata date {meta_date}"
                    )
    if errors:
        print("TEMPORAL_INTEGRITY_FAILED")
        for error in errors:
            print(f"- {error}")
        raise SystemExit(1)
    print("TEMPORAL_INTEGRITY_OK")


if __name__ == "__main__":
    main()
