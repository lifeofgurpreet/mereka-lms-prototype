#!/usr/bin/env python3
"""Verify tracked generated markdown docs carry the standard do-not-edit banner."""

from __future__ import annotations

from pathlib import Path
import sys


EXPECTED = "Generated file. Do not hand-edit. Regenerate from the ADR source inputs."
TARGETS = [
    Path("generated/decision-maps/adr-decision-map.md"),
    *sorted(
        path for path in Path("generated/adr-bundles").glob("*.md")
        if path.name != "README.md"
    ),
]


def main() -> int:
    failures: list[str] = []
    checked = 0
    for path in TARGETS:
        if not path.exists():
            failures.append(f"missing: {path}")
            continue
        checked += 1
        text = path.read_text(encoding="utf-8")
        head = "\n".join(text.splitlines()[:6])
        if EXPECTED not in head:
            failures.append(f"missing banner: {path}")
    if failures:
        print("GENERATED_DOC_BANNERS_FAIL")
        for item in failures:
            print(f"- {item}")
        return 1
    print(f"GENERATED_DOC_BANNERS_OK checked={checked}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
