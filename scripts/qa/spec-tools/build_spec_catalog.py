#!/usr/bin/env python3
"""Generate a machine-readable catalog for normative, proposal, and plan lanes."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import date, datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.specs.spec_tooling import (
    inferred_normativity,
    inferred_spec_class,
    iter_lane_files,
    parse_frontmatter,
    pick,
    read_title,
    relative_path,
)

AC_TOKEN = "- [ ] AC-"


def count_acceptance_criteria(path: Path) -> int:
    return path.read_text().count(AC_TOKEN)


def rel(path: Path, repo_root: Path) -> str:
    return relative_path(path, repo_root)


def to_json_value(value: object) -> object:
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    if isinstance(value, list):
        return [to_json_value(item) for item in value]
    if isinstance(value, dict):
        return {str(key): to_json_value(item) for key, item in value.items()}
    return value


def normalize_related_path(value: object, default_prefix: str) -> str | None:
    if not value:
        return None
    text = str(value)
    if text.startswith("specs/"):
        return text
    if text.startswith("plans/"):
        return f"specs/{text}"
    if text.startswith("proposals/"):
        return f"specs/{text}"
    return f"{default_prefix}/{text}"


def related_links(path: Path, lane: str, frontmatter: dict, repo_root: Path) -> dict[str, str | None]:
    specs_root = repo_root / "specs"
    plans_root = specs_root / "plans"
    stem = path.stem

    if lane in {"normative", "proposal"}:
        base_name = stem.replace("_spec", "")
        plan_path = plans_root / f"{base_name}_plan.md"
        testplan_path = plans_root / f"{base_name}_testplan.md"
        generated_testmap_path = (
            specs_root / "_generated" / "testmaps" / f"{base_name}_spec.testmap.yml"
        )
        legacy_testmap_path = specs_root / "testmaps" / f"{base_name}_spec.testmap.yml"
        return {
            "source_spec": None,
            "source_plan": None,
            "plan": rel(plan_path, repo_root) if plan_path.exists() else None,
            "testplan": rel(testplan_path, repo_root) if testplan_path.exists() else None,
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
        }

    source_spec = pick(frontmatter, "spec", "source_spec")
    source_plan = pick(frontmatter, "plan", "source_plan")
    return {
        "source_spec": normalize_related_path(source_spec, "specs"),
        "source_plan": normalize_related_path(source_plan, "specs/plans"),
        "plan": None,
        "testplan": None,
        "generated_testmap": None,
        "legacy_testmap": None,
    }


def inferred_doc_type(lane: str, frontmatter: dict) -> str:
    spec_class = str(inferred_spec_class(lane, frontmatter) or "")
    normativity = str(inferred_normativity(lane, frontmatter) or "")
    if spec_class == "generated" or normativity == "generated":
        return "generated"
    if lane in {"plan", "testplan"}:
        return lane
    return "spec"


def build_catalog(repo_root: Path) -> dict:
    entries = []

    for lane, path in iter_lane_files(repo_root):
        frontmatter = parse_frontmatter(path)
        links = related_links(path, lane, frontmatter, repo_root)
        entries.append(
            {
                "path": rel(path, repo_root),
                "lane": lane,
                "doc_type": inferred_doc_type(lane, frontmatter),
                "id": to_json_value(pick(frontmatter, "id")),
                "title": to_json_value(pick(frontmatter, "title") or read_title(path)),
                "status": to_json_value(pick(frontmatter, "status")),
                "spec_class": to_json_value(inferred_spec_class(lane, frontmatter)),
                "owner": to_json_value(pick(frontmatter, "owner")),
                "domain": to_json_value(pick(frontmatter, "domain")),
                "normativity": to_json_value(inferred_normativity(lane, frontmatter)),
                "created": to_json_value(pick(frontmatter, "created")),
                "last_reviewed": to_json_value(pick(frontmatter, "last_reviewed", "last_updated", "updated")),
                "review_due": to_json_value(pick(frontmatter, "review_due")),
                "summary": to_json_value(pick(frontmatter, "summary")),
                "tags": to_json_value(pick(frontmatter, "tags") or []),
                "version": to_json_value(pick(frontmatter, "version")),
                "acceptance_criteria_count": count_acceptance_criteria(path),
                "links": to_json_value(links),
            }
        )

    return {
        "generated_by": "scripts/qa/spec-tools/build_spec_catalog.py",
        "root": "specs",
        "taxonomy": "specs/standards/spec-taxonomy.yaml",
        "entry_count": len(entries),
        "entries": sorted(entries, key=lambda item: item["path"]),
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
