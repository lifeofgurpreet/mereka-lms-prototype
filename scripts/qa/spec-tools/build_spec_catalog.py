#!/usr/bin/env python3
"""Generate a machine-readable catalog for top-level specs."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

import yaml

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
AC_RE = re.compile(r"- \[ \] AC-")


def pick(frontmatter: dict, *keys: str) -> object:
    for key in keys:
        value = frontmatter.get(key)
        if value not in (None, "", []):
            return value
    return None


def parse_frontmatter(path: Path) -> dict:
    text = path.read_text()
    match = FRONTMATTER_RE.match(text)
    if not match:
        return {}
    data = yaml.safe_load(match.group(1)) or {}
    return data if isinstance(data, dict) else {}


def count_acceptance_criteria(path: Path) -> int:
    return len(AC_RE.findall(path.read_text()))


def rel(path: Path, repo_root: Path) -> str:
    return path.relative_to(repo_root).as_posix()


def build_catalog(repo_root: Path) -> dict:
    specs_root = repo_root / "specs"
    entries = []

    for spec_path in sorted(specs_root.glob("*_spec.md")):
        frontmatter = parse_frontmatter(spec_path)
        stem = spec_path.stem.replace("_spec", "")
        plan_path = specs_root / "plans" / f"{stem}_plan.md"
        testplan_path = specs_root / "plans" / f"{stem}_testplan.md"
        generated_testmap_path = (
            specs_root / "_generated" / "testmaps" / f"{stem}_spec.testmap.yml"
        )
        legacy_testmap_path = specs_root / "testmaps" / f"{stem}_spec.testmap.yml"

        entries.append(
            {
                "path": rel(spec_path, repo_root),
                "id": pick(frontmatter, "id"),
                "title": pick(frontmatter, "title") or spec_path.stem,
                "status": pick(frontmatter, "status"),
                "spec_class": pick(frontmatter, "spec_class", "type"),
                "owner": pick(frontmatter, "owner"),
                "domain": pick(frontmatter, "domain"),
                "normativity": pick(frontmatter, "normativity"),
                "created": pick(frontmatter, "created"),
                "last_reviewed": pick(frontmatter, "last_reviewed", "last_updated"),
                "review_due": pick(frontmatter, "review_due"),
                "summary": pick(frontmatter, "summary"),
                "tags": pick(frontmatter, "tags") or [],
                "version": pick(frontmatter, "version"),
                "acceptance_criteria_count": count_acceptance_criteria(spec_path),
                "links": {
                    "plan": rel(plan_path, repo_root) if plan_path.exists() else None,
                    "testplan": (
                        rel(testplan_path, repo_root) if testplan_path.exists() else None
                    ),
                    "generated_testmap": (
                        rel(generated_testmap_path, repo_root)
                        if generated_testmap_path.exists()
                        else None
                    ),
                    "legacy_testmap": (
                        rel(legacy_testmap_path, repo_root)
                        if legacy_testmap_path.exists()
                        else None
                    ),
                },
            }
        )

    return {
        "generated_by": "scripts/qa/spec-tools/build_spec_catalog.py",
        "root": "specs",
        "taxonomy": "specs/standards/spec-taxonomy.yaml",
        "entry_count": len(entries),
        "entries": entries,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate specs/_generated/spec-catalog.json")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default="specs/catalog.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    catalog = build_catalog(repo_root)
    rendered = json.dumps(catalog, indent=2, sort_keys=True) + "\n"

    if args.check:
        if not output_path.exists():
            raise SystemExit(f"Missing generated file: {output_path}")
        current = output_path.read_text()
        if current != rendered:
            raise SystemExit("SPEC_CATALOG_DRIFT")
        print(f"SPEC_CATALOG_OK entries={catalog['entry_count']} mode=check")
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
    print(f"SPEC_CATALOG_OK entries={catalog['entry_count']} mode=write")


if __name__ == "__main__":
    main()
