#!/usr/bin/env python3
"""Verify docs catalog duplicate-canonical and changed-file coverage contracts."""

from __future__ import annotations

import argparse
import json
import subprocess
from collections import defaultdict
from pathlib import Path

WINNING_PREFIXES = (
    "docs/ops/",
    "docs/guides/",
    "docs/reference/",
    "docs/policies/",
    "docs/evidence/",
    "docs/status/",
    "docs/concepts/architecture/",
    "docs/adr/",
)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", default=".")
    p.add_argument("--range", default="HEAD~1...HEAD")
    p.add_argument("--catalog", default="generated/catalogs/docs-catalog.json")
    p.add_argument("--summary-file", default="")
    p.add_argument("paths", nargs="*")
    return p.parse_args()


def changed_paths(repo_root: Path, diff_range: str) -> list[str]:
    result = subprocess.run(
        [
            "git",
            "diff",
            "--name-only",
            diff_range,
            "--",
            "docs/**",
            "generated/catalogs/docs-catalog.json",
        ],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def main() -> int:
    args = parse_args()
    repo_root = Path(args.root).resolve()
    catalog_path = repo_root / args.catalog
    payload = json.loads(catalog_path.read_text(encoding="utf-8"))
    changed = args.paths or changed_paths(repo_root, args.range)

    duplicate_groups: dict[str, list[str]] = {}
    by_group: dict[str, list[str]] = defaultdict(list)
    for item in payload:
        if item.get("status") != "canonical":
            continue
        group = item.get("canonical_conflict_group")
        if group:
            by_group[group].append(item.get("path", ""))
    for group, paths in sorted(by_group.items()):
        if len(paths) > 1:
            duplicate_groups[group] = sorted(paths)

    catalog_paths = {item.get("path") for item in payload}
    uncovered_changed_docs: list[str] = []
    changed_winning_docs = [
        p for p in changed
        if p.startswith(WINNING_PREFIXES) and (repo_root / p).exists() and (repo_root / p).is_file()
    ]
    source_catalog_touched = "generated/catalogs/docs-catalog.json" in changed
    for rel in changed:
        if not rel.startswith(WINNING_PREFIXES):
            continue
        full = repo_root / rel
        if not full.exists() or not full.is_file():
            continue
        catalog_key = rel.removeprefix("docs/")
        if catalog_key not in catalog_paths:
            uncovered_changed_docs.append(rel)
    catalog_update_missing = bool(changed_winning_docs) and not source_catalog_touched

    summary = {
        "status": "fail" if duplicate_groups or uncovered_changed_docs or catalog_update_missing else "pass",
        "range": args.range,
        "duplicate_canonical_groups": duplicate_groups,
        "changed_docs_checked": len(changed_winning_docs),
        "uncovered_changed_docs": uncovered_changed_docs,
        "source_catalog_touched": source_catalog_touched,
        "catalog_update_missing": catalog_update_missing,
    }
    if args.summary_file:
        Path(args.summary_file).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    if duplicate_groups or uncovered_changed_docs or catalog_update_missing:
        print("DOCS_CATALOG_GOVERNANCE_FAIL")
        for group, paths in duplicate_groups.items():
            print(f"- duplicate canonical group {group}: {', '.join(paths)}")
        for path in uncovered_changed_docs:
            print(f"- changed winning-root doc missing catalog entry: {path}")
        if catalog_update_missing:
            print("- changed winning-root docs require a matching update to generated/catalogs/docs-catalog.json")
        return 1

    print(
        "DOCS_CATALOG_GOVERNANCE_OK "
        f"changed_docs_checked={summary['changed_docs_checked']} duplicate_groups=0 uncovered_changed_docs=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
