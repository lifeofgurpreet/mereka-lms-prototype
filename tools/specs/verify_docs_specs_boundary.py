#!/usr/bin/env python3
"""Verify the explicit docs/specs twin-root boundary."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def load_docs_catalog(path: Path) -> list[dict]:
    data = json.loads(path.read_text())
    if not isinstance(data, list):
        raise ValueError(f"{path} must be a JSON list")
    return data


def load_specs_catalog(path: Path) -> dict:
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise ValueError(f"{path} must be a JSON object")
    return data


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify docs/specs boundary invariants."
    )
    parser.add_argument(
        "--repo-root",
        default=".",
        help="Repository root containing docs/ and specs/",
    )
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    docs_catalog = load_docs_catalog(repo_root / "docs" / "catalog.json")
    specs_catalog = load_specs_catalog(repo_root / "specs" / "catalog.json")

    errors: list[str] = []

    docs_spec_paths = sorted(
        str(entry.get("path", ""))
        for entry in docs_catalog
        if str(entry.get("path", "")).startswith("specs/")
    )
    if docs_spec_paths:
        errors.append(
            "docs/catalog.json contains spec-root paths: "
            + ", ".join(docs_spec_paths[:10])
        )

    if specs_catalog.get("root") != "specs":
        errors.append(
            f"specs/catalog.json root must be 'specs' (got {specs_catalog.get('root')!r})"
        )

    entries = specs_catalog.get("entries", [])
    if not isinstance(entries, list):
        errors.append("specs/catalog.json entries must be a list")
        entries = []

    non_specs_paths = sorted(
        str(entry.get("path", ""))
        for entry in entries
        if not str(entry.get("path", "")).startswith("specs/")
    )
    if non_specs_paths:
        errors.append(
            "specs/catalog.json contains non-spec paths: "
            + ", ".join(non_specs_paths[:10])
        )

    for entry in entries:
        path = str(entry.get("path", ""))
        spec_class = entry.get("spec_class")
        normativity = entry.get("normativity")
        if path.startswith("specs/plans/") and spec_class != "plan":
            errors.append(
                f"{path} must use spec_class=plan (got {spec_class!r})"
            )
        if path.startswith("specs/plans/") and normativity != "planning":
            errors.append(
                f"{path} must use normativity=planning (got {normativity!r})"
            )
        if path.startswith("specs/proposals/") and spec_class != "proposal":
            errors.append(
                f"{path} must use spec_class=proposal (got {spec_class!r})"
            )
        if path.startswith("specs/proposals/") and normativity != "proposed":
            errors.append(
                f"{path} must use normativity=proposed (got {normativity!r})"
            )

    if errors:
        print("DOCS_SPECS_BOUNDARY_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        "DOCS_SPECS_BOUNDARY_OK "
        f"docs_entries={len(docs_catalog)} specs_entries={len(entries)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
