#!/usr/bin/env python3
"""Verify spec metadata values against the controlled taxonomy."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import yaml

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)


def parse_frontmatter(path: Path) -> dict:
    match = FRONTMATTER_RE.match(path.read_text())
    if not match:
        return {}
    data = yaml.safe_load(match.group(1)) or {}
    return data if isinstance(data, dict) else {}


def load_taxonomy(path: Path) -> dict[str, set[str]]:
    data = yaml.safe_load(path.read_text()) or {}
    return {
        "status": set(data.get("status", [])),
        "spec_class": set(data.get("spec_class", [])),
        "normativity": set(data.get("normativity", [])),
        "domain": set(data.get("domain", [])),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    taxonomy = load_taxonomy(repo_root / "specs" / "standards" / "spec-taxonomy.yaml")
    specs = sorted((repo_root / "specs").glob("*_spec.md"))
    invalid = []
    legacy_status_hits = 0

    for spec in specs:
        fm = parse_frontmatter(spec)
        checks = {
            "status": fm.get("status"),
            "spec_class": fm.get("spec_class"),
            "normativity": fm.get("normativity"),
            "domain": fm.get("domain"),
        }
        for key, value in checks.items():
            if value in (None, "", []):
                continue
            if value not in taxonomy[key]:
                invalid.append((spec.relative_to(repo_root).as_posix(), key, value))
            elif key == "status" and value in {"completed", "in_progress", "deferred"}:
                legacy_status_hits += 1

    if invalid:
        for path, key, value in invalid:
            print(f"SPEC_TAXONOMY_FAIL {path} field={key} value={value}")
        raise SystemExit(1)

    print(
        f"SPEC_TAXONOMY_OK files_checked={len(specs)} legacy_status_hits={legacy_status_hits}"
    )


if __name__ == "__main__":
    main()
