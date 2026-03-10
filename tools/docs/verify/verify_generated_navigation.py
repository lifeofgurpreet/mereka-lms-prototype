#!/usr/bin/env python3
"""Verify generated markdown navigation resolves to canonical files."""

from __future__ import annotations

import re
from pathlib import Path


LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
ROOT = Path(".").resolve()
SCAN_DIRS = [
    Path("generated/adr-bundles"),
    Path("generated/decision-maps"),
]


def is_canonical_target(target: Path) -> bool:
    try:
        relative = target.resolve().relative_to(ROOT)
    except ValueError:
        return False
    return str(relative).startswith(("docs/adr/", "docs/", "generated/"))


def main() -> None:
    errors: list[str] = []
    for directory in SCAN_DIRS:
        if not directory.exists():
            continue
        for path in sorted(directory.glob("*.md")):
            text = path.read_text(encoding="utf-8", errors="ignore")
            for target in LINK_RE.findall(text):
                if target.startswith(("http://", "https://", "#", "mailto:")):
                    continue
                resolved = (path.parent / target).resolve()
                if not resolved.exists():
                    errors.append(f"{path}: broken link target {target}")
                    continue
                if not is_canonical_target(resolved):
                    errors.append(f"{path}: non-canonical link target {target}")
    if errors:
        print("GENERATED_NAVIGATION_FAILED")
        for error in errors:
            print(f"- {error}")
        raise SystemExit(1)
    print("GENERATED_NAVIGATION_OK")


if __name__ == "__main__":
    main()
