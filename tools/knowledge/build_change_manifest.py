#!/usr/bin/env python3
"""Build the Wave 5 machine-readable change manifest for a diff range."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.change_runtime import build_changed_entry, changed_files, load_runtime_inputs


def build_manifest(repo_root: Path, range_spec: str) -> dict:
    runtime = load_runtime_inputs(repo_root)
    files = changed_files(repo_root, range_spec)
    entries = [
        build_changed_entry(
            repo_root,
            rel_path,
            runtime["ownership_map"],
            runtime["change_classes"],
            runtime["evidence_rules"],
            runtime["review_rules"],
        )
        for rel_path in files
    ]

    change_classes = sorted({entry["change_class"] for entry in entries})
    touched_roots = sorted({entry["root"] for entry in entries if entry["root"] != "other"})
    required_reviewers = sorted(
        {
            reviewer
            for entry in entries
            for reviewer in entry["review"].get("required_reviewers", [])
        }
    )
    impacted_surfaces = sorted(
        {
            surface
            for entry in entries
            for surface in entry.get("impacted_truth_surfaces", [])
        }
    )

    return {
        "generated_by": "tools/knowledge/build_change_manifest.py",
        "range": range_spec,
        "change_count": len(entries),
        "changed_roots": touched_roots,
        "change_classes": change_classes,
        "required_reviewers": required_reviewers,
        "impacted_truth_surfaces": impacted_surfaces,
        "entries": entries,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    parser.add_argument("--output", default="generated/knowledge/change-manifest.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    manifest = build_manifest(repo_root, args.range_spec)
    rendered = json.dumps(manifest, indent=2, sort_keys=True) + "\n"

    if args.check:
        if not output_path.exists():
            raise SystemExit(f"Missing generated file: {output_path}")
        if output_path.read_text() != rendered:
            raise SystemExit("CHANGE_MANIFEST_DRIFT")
        print(f"CHANGE_MANIFEST_OK changes={manifest['change_count']} mode=check")
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
    print(f"CHANGE_MANIFEST_OK changes={manifest['change_count']} mode=write")


if __name__ == "__main__":
    main()
