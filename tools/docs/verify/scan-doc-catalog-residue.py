#!/usr/bin/env python3
"""Scan docs-catalog residue across winning roots."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

WINNING_ROOTS = (
    "adr/",
    "concepts/architecture/",
    "evidence/",
    "guides/",
    "ops/",
    "policies/",
    "reference/",
    "status/",
)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", default=".")
    p.add_argument("--catalog", default="generated/catalogs/docs-catalog.json")
    p.add_argument("--summary-file", default="")
    p.add_argument("--limit", type=int, default=50)
    p.add_argument("--fail-on-residue", action="store_true")
    return p.parse_args()


def in_winning_root(path: str) -> bool:
    return path.startswith(WINNING_ROOTS)


def is_catalogable_doc(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() == ".md"


def main() -> int:
    args = parse_args()
    repo_root = Path(args.root).resolve()
    docs_root = repo_root / "docs"
    catalog_path = repo_root / args.catalog
    payload = json.loads(catalog_path.read_text(encoding="utf-8"))

    catalog_paths = set()
    duplicate_groups: dict[str, list[str]] = defaultdict(list)
    canonical_entries = 0
    for item in payload:
        path = item.get("path")
        if not path:
            continue
        catalog_paths.add(path)
        if item.get("status") == "canonical":
            canonical_entries += 1
            group = item.get("canonical_conflict_group")
            if group:
                duplicate_groups[group].append(path)

    filesystem_paths: set[str] = set()
    for root in WINNING_ROOTS:
        full_root = docs_root / root
        if not full_root.exists():
            continue
        for p in full_root.rglob("*"):
            if is_catalogable_doc(p):
                filesystem_paths.add(p.relative_to(docs_root).as_posix())

    uncataloged_winning_docs = sorted(filesystem_paths - catalog_paths)
    stale_catalog_entries = sorted(path for path in catalog_paths if in_winning_root(path) and not (docs_root / path).exists())
    duplicate_canonical_groups = {
        group: sorted(paths)
        for group, paths in sorted(duplicate_groups.items())
        if len(paths) > 1
    }

    failed = bool(uncataloged_winning_docs or stale_catalog_entries or duplicate_canonical_groups)
    summary = {
        "status": "fail" if failed and args.fail_on_residue else "advisory",
        "catalog_path": str(catalog_path),
        "winning_roots": list(WINNING_ROOTS),
        "canonical_entries": canonical_entries,
        "uncataloged_winning_docs_count": len(uncataloged_winning_docs),
        "uncataloged_winning_docs_sample": uncataloged_winning_docs[: args.limit],
        "stale_catalog_entries_count": len(stale_catalog_entries),
        "stale_catalog_entries_sample": stale_catalog_entries[: args.limit],
        "duplicate_canonical_groups_count": len(duplicate_canonical_groups),
        "duplicate_canonical_groups": duplicate_canonical_groups,
    }
    if args.summary_file:
        Path(args.summary_file).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    label = "DOCS_CATALOG_RESIDUE_FAIL" if failed and args.fail_on_residue else "DOCS_CATALOG_RESIDUE_ADVISORY"
    print(
        f"{label} "
        f"uncataloged_winning_docs={summary['uncataloged_winning_docs_count']} "
        f"stale_catalog_entries={summary['stale_catalog_entries_count']} "
        f"duplicate_groups={summary['duplicate_canonical_groups_count']}"
    )
    if failed and args.fail_on_residue:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
