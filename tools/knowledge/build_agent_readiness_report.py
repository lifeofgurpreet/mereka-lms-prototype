#!/usr/bin/env python3
"""Build the Wave 8 agent readiness report."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.build_agent_entrypoints import build_entrypoints
from tools.knowledge.build_agent_task_bundles import FILE_NAME_MAP, build_bundle


def load_yaml(path: Path) -> dict[str, Any]:
    return yaml.safe_load(path.read_text())


def compute_score(hit: int, total: int) -> int:
    if total <= 0:
        return 0
    return round((hit / total) * 100)


def build_report(repo_root: Path, range_spec: str) -> dict[str, Any]:
    taxonomy = load_yaml(repo_root / "docs" / "meta" / "knowledge" / "AGENT_TASK_TAXONOMY.yaml")["task_types"]
    entrypoints = build_entrypoints(repo_root)
    expected_tasks = set(taxonomy)
    bundle_dir = repo_root / "generated" / "knowledge" / "agent-task-bundles"
    actual_bundle_files = {path.name for path in bundle_dir.glob("*.md")}
    expected_bundle_files = set(FILE_NAME_MAP.values())

    unresolved_domains = entrypoints["unresolved_domains"]
    unresolved_tasks = sorted(
        task_type for task_type, file_name in FILE_NAME_MAP.items() if file_name not in actual_bundle_files
    )

    forbidden_surface_leaks: list[str] = []
    review_ready = 0
    evidence_ready = 0
    cross_repo_ready = 0

    for task_type in sorted(expected_tasks):
        bundle = build_bundle(repo_root, task_type)
        if bundle["required_reviewers"]:
            review_ready += 1
        if bundle["required_evidence"]:
            evidence_ready += 1
        if bundle["cross_repo_fallout"]["overall_verdict"] != "not_applicable":
            cross_repo_ready += 1

        for item in bundle["read_first"]:
            if item["lane"] == "archive":
                forbidden_surface_leaks.append(f"{task_type}:read_first:{item['path']}")
    report = {
        "generated_by": "tools/knowledge/build_agent_readiness_report.py",
        "range": range_spec,
        "scores": {
            "domain_entrypoint_coverage": compute_score(entrypoints["domain_count"], len(entrypoints["domains"]) + len(unresolved_domains)),
            "task_bundle_coverage": compute_score(len(expected_bundle_files & actual_bundle_files), len(expected_bundle_files)),
            "canonicality": compute_score(len(expected_tasks) - len(forbidden_surface_leaks), len(expected_tasks)),
            "determinism": 100 if actual_bundle_files == expected_bundle_files else 0,
            "review_clarity": compute_score(review_ready, len(expected_tasks)),
            "evidence_clarity": compute_score(evidence_ready, len(expected_tasks)),
            "cross_repo_awareness": compute_score(cross_repo_ready, len(expected_tasks)),
        },
        "unresolved_domains": unresolved_domains,
        "unresolved_tasks": unresolved_tasks,
        "forbidden_surface_leaks": sorted(set(forbidden_surface_leaks)),
        "domain_count": entrypoints["domain_count"],
        "task_bundle_count": len(actual_bundle_files & expected_bundle_files),
        "expected_task_bundle_count": len(expected_bundle_files),
    }
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", default="origin/main...HEAD")
    parser.add_argument("--output", default="generated/knowledge/agent-readiness-report.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    payload = build_report(repo_root, args.range)
    rendered = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    output_path = repo_root / args.output
    if args.check:
        if not output_path.exists() or output_path.read_text() != rendered:
            raise SystemExit("AGENT_READINESS_REPORT_DRIFT")
    else:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(rendered)
    print(
        f"AGENT_READINESS_REPORT_OK mode={'check' if args.check else 'write'} "
        f"domains={payload['domain_count']} bundles={payload['task_bundle_count']} "
        f"forbidden_surface_leaks={len(payload['forbidden_surface_leaks'])}"
    )


if __name__ == "__main__":
    main()
