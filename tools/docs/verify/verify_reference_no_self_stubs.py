#!/usr/bin/env python3
"""Fail if docs/reference contains self-referential superseded stubs."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    ref_root = repo_root / "docs" / "reference"
    errors: list[str] = []

    for path in sorted(ref_root.rglob("*.md")):
        rel = path.relative_to(repo_root).as_posix()
        text = path.read_text(encoding="utf-8", errors="ignore")
        if "# Superseded Path Notice" not in text:
            continue
        if f"Canonical document: `{rel}`" in text:
            errors.append(f"self-referential superseded stub in canonical reference root: {rel}")

    if errors:
        print("REFERENCE_SELF_STUBS_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("REFERENCE_SELF_STUBS_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
