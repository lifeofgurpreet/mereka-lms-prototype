#!/usr/bin/env python3
"""Verify required frontmatter fields for top-level specs."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import yaml

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
REQUIRED = {
    "title": ("title",),
    "status": ("status",),
    "owner": ("owner",),
    "spec_class_or_type": ("spec_class", "type"),
    "normativity_or_vehicle": ("normativity", "vehicle"),
    "last_reviewed_or_last_updated": ("last_reviewed", "last_updated"),
}


def parse_frontmatter(path: Path) -> dict:
    match = FRONTMATTER_RE.match(path.read_text())
    if not match:
        return {}
    data = yaml.safe_load(match.group(1)) or {}
    return data if isinstance(data, dict) else {}


def has_any(data: dict, keys: tuple[str, ...]) -> bool:
    return any(data.get(key) not in (None, "", []) for key in keys)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    specs = sorted((repo_root / "specs").glob("*_spec.md"))
    missing = []
    for spec in specs:
        frontmatter = parse_frontmatter(spec)
        missing_fields = [
            label for label, keys in REQUIRED.items() if not has_any(frontmatter, keys)
        ]
        if missing_fields:
            missing.append((spec.relative_to(repo_root).as_posix(), missing_fields))

    if missing:
        for path, fields in missing:
            print(f"SPEC_FRONTMATTER_FAIL {path} missing={','.join(fields)}")
        raise SystemExit(1)

    print(f"SPEC_FRONTMATTER_OK files_checked={len(specs)}")


if __name__ == "__main__":
    main()
