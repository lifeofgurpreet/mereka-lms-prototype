#!/usr/bin/env python3
"""Build the Wave 5 machine-readable truth impact report for a diff range."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.build_change_manifest import build_manifest


def load_catalog(repo_root: Path) -> dict[str, dict]:
    catalog_path = repo_root / "generated" / "catalogs" / "knowledge-catalog.json"
    catalog = json.loads(catalog_path.read_text())
    return {entry["path"]: entry for entry in catalog.get("entries", [])}


def classify_surfaces(paths: list[str], catalog_index: dict[str, dict]) -> dict[str, list[str]]:
    buckets = {
        "adrs": [],
        "plans_testplans": [],
        "wrappers": [],
        "runbooks": [],
        "generated_surfaces": [],
        "docs_support": [],
        "normative_specs": [],
        "proposal_specs": [],
        "other": [],
    }
    for path in paths:
        entry = catalog_index.get(path)
        if not entry:
            buckets["other"].append(path)
            continue
        lane = entry.get("lane")
        classification = entry.get("classification")
        if lane == "adr":
            buckets["adrs"].append(path)
        elif lane in {"plan", "testplan"}:
            buckets["plans_testplans"].append(path)
        elif classification == "compatibility":
            buckets["wrappers"].append(path)
        elif lane == "runbook":
            buckets["runbooks"].append(path)
        elif classification == "generated" or lane == "generated":
            buckets["generated_surfaces"].append(path)
        elif entry.get("root") == "specs" and lane == "normative":
            buckets["normative_specs"].append(path)
        elif entry.get("root") == "specs" and lane == "proposal":
            buckets["proposal_specs"].append(path)
        elif entry.get("root") == "docs":
            buckets["docs_support"].append(path)
        else:
            buckets["other"].append(path)

    return {name: sorted(set(values)) for name, values in buckets.items()}


def inferred_related_paths(entry: dict, catalog_index: dict[str, dict]) -> list[str]:
    path = entry["path"]
    root = entry.get("root")
    lane = entry.get("lane")
    related = set(entry.get("impacted_truth_surfaces", []))

    if root == "specs":
        stem = Path(path).name
        base = stem.replace("_spec.md", "").replace("_plan.md", "").replace("_testplan.md", "")
        candidates = [
            f"specs/{base}_spec.md",
            f"specs/proposals/{base}_spec.md",
            f"specs/plans/{base}_plan.md",
            f"specs/plans/{base}_testplan.md",
            "specs/catalog.json",
            "specs/_generated/graph.json",
            "specs/_generated/indexes/spec-read-first.md",
            "specs/_generated/bundles/00-spec-hot-path.md",
        ]
        if lane == "proposal":
            candidates.append(f"specs/{base}_spec.md")
        for candidate in candidates:
            if candidate in catalog_index or (REPO_ROOT / candidate).exists():
                related.add(candidate)

    if root == "docs":
        related.update(
            {
                "docs/catalog.json",
                "generated/catalogs/docs-catalog.json",
                "generated/catalogs/knowledge-catalog.json",
                "generated/graphs/knowledge-graph.json",
            }
        )

    return sorted(related)


def build_report(repo_root: Path, range_spec: str) -> dict:
    manifest = build_manifest(repo_root, range_spec)
    catalog_index = load_catalog(repo_root)
    per_change = []
    aggregate_paths = set()

    for entry in manifest["entries"]:
        related = inferred_related_paths(entry, catalog_index)
        aggregate_paths.update(related)
        per_change.append(
            {
                "path": entry["path"],
                "change_class": entry["change_class"],
                "change_risk": entry.get("change_risk", "low"),
                "required_reviewers": entry.get("review", {}).get("required_reviewers", []),
                "required_evidence": {
                    key: value
                    for key, value in (entry.get("evidence") or {}).items()
                    if value
                },
                "impacts": classify_surfaces(related, catalog_index),
            }
        )

    aggregate_buckets = classify_surfaces(sorted(aggregate_paths), catalog_index)
    impacted_lane_counts = Counter(
        f"{entry.get('root')}:{entry.get('lane')}"
        for entry in manifest["entries"]
        if entry.get("root") in {"docs", "specs"}
    )

    return {
        "generated_by": "tools/knowledge/build_truth_impact_report.py",
        "range": range_spec,
        "change_count": manifest["change_count"],
        "required_reviewers": manifest["required_reviewers"],
        "change_classes": manifest["change_classes"],
        "impacted_lane_counts": dict(sorted(impacted_lane_counts.items())),
        "aggregate_impacts": aggregate_buckets,
        "per_change": per_change,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    parser.add_argument("--output", default="generated/knowledge/truth-impact-report.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    report = build_report(repo_root, args.range_spec)
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"

    if args.check:
        if not output_path.exists():
            raise SystemExit(f"Missing generated file: {output_path}")
        if output_path.read_text() != rendered:
            raise SystemExit("TRUTH_IMPACT_REPORT_DRIFT")
        print("TRUTH_IMPACT_REPORT_OK mode=check")
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
    print("TRUTH_IMPACT_REPORT_OK mode=write")


if __name__ == "__main__":
    main()
