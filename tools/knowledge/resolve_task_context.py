#!/usr/bin/env python3
"""Resolve Wave 7 task context from an explicit task type or a diff range."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.skill_runtime import (
    aggregate_commands,
    aggregate_reviewers_and_evidence,
    bundle_read_first,
    changed_files,
    classify_task_candidates,
    confidence_for_candidates,
    is_canonical_surface,
    load_runtime_inputs,
)


def resolve_context(repo_root: Path, range_spec: str, explicit_task_type: str | None = None) -> dict:
    runtime = load_runtime_inputs(repo_root)
    taxonomy = runtime["taxonomy"]
    task_order = taxonomy["task_resolution_order"]
    changed = changed_files(repo_root, range_spec)
    entry_index = {entry["path"]: entry for entry in runtime["change_manifest"].get("entries", [])}
    cross_entries = runtime["cross_repo_manifest"].get("entries", [])
    truth_lane_counts = runtime["truth_impact"].get("impacted_lane_counts", {})

    per_file = []
    aggregate_scores = {task_type: 0 for task_type in task_order}
    for rel_path in changed:
        entry = entry_index.get(rel_path)
        candidates = classify_task_candidates(rel_path, runtime, entry)
        per_file.append({"path": rel_path, "candidates": candidates})
        for candidate in candidates:
            aggregate_scores[candidate["task_type"]] += candidate["score"]

    aggregate_candidates = [
        {"task_type": task_type, "score": aggregate_scores[task_type]}
        for task_type in task_order
        if aggregate_scores[task_type] > 0
    ]
    if not aggregate_candidates:
        aggregate_candidates = [{"task_type": "generated_surface_refresh", "score": 1}]
    aggregate_candidates.sort(key=lambda item: (-item["score"], task_order.index(item["task_type"])))

    primary = explicit_task_type or aggregate_candidates[0]["task_type"]
    secondary = [item["task_type"] for item in aggregate_candidates[1:4]]
    confidence, why = confidence_for_candidates(aggregate_candidates[:2] if len(aggregate_candidates) > 1 else aggregate_candidates)
    if explicit_task_type:
        confidence = "high"
        why = f"explicit task type override selected {explicit_task_type}"

    matched_files = [
        item["path"]
        for item in per_file
        if any(candidate["task_type"] == primary for candidate in item["candidates"])
    ]
    matched_entries = [entry_index[path] for path in matched_files if path in entry_index]
    touched_services = sorted(
        {
            service
            for cross_entry in cross_entries
            if cross_entry["path"] in matched_files
            for service in cross_entry.get("touched_services", [])
        }
    )

    read_first = bundle_read_first(repo_root, runtime, primary)
    affected_truth_surfaces = sorted(
        {
            surface
            for entry in matched_entries
            for surface in entry.get("impacted_truth_surfaces", [])
            if is_canonical_surface(repo_root, surface)
        }
    )
    reviewers, evidence = aggregate_reviewers_and_evidence(runtime, primary, matched_entries, touched_services)

    generated_surfaces = [
        surface
        for surface in (
            runtime["bundle_rules"]["required_generated_surfaces_high_risk"]
            if taxonomy["task_types"][primary]["risk"] == "high"
            else [
                "generated/knowledge/change-manifest.json",
                "generated/knowledge/task-context-report.json",
                "generated/knowledge/skill-index.json",
            ]
        )
        if is_canonical_surface(repo_root, surface)
    ]
    if primary in {"cross_repo_contract_change", "release_or_runtime_change"}:
        for surface in [
            "generated/contracts/cross-repo-manifest.json",
            "generated/contracts/deployment-impact-report.json",
            "generated/contracts/release-obligations.md",
        ]:
            if is_canonical_surface(repo_root, surface) and surface not in generated_surfaces:
                generated_surfaces.append(surface)

    dependency_index = {item["service"]: item for item in runtime["deployment_impact"].get("deployment_impacts", [])}
    cross_repo_dependencies = [
        {
            "service": service,
            "verdict": dependency_index.get(service, {}).get("cross_repo_verdict", runtime["cross_repo_manifest"].get("overall_verdict")),
            "reviewers": dependency_index.get(service, {}).get("required_reviewers", []),
            "unknowns": dependency_index.get(service, {}).get("unknowns", []),
        }
        for service in touched_services
    ]

    return {
        "generated_by": "tools/knowledge/resolve_task_context.py",
        "range": range_spec,
        "primary_task_type": primary,
        "secondary_task_types": secondary,
        "confidence": confidence,
        "why": why,
        "matched_files": matched_files,
        "canonical_roots_touched": sorted(
            {
                entry["root"]
                for entry in matched_entries
                if entry.get("root") in {"docs", "specs"}
            }
        ),
        "cross_repo_surfaces_touched": touched_services,
        "generated_surfaces_implicated": generated_surfaces,
        "reviewers_required": reviewers,
        "evidence_required": evidence,
        "commands_required": aggregate_commands(runtime, primary),
        "task_type_candidates": aggregate_candidates,
        "per_file_candidates": per_file,
        "affected_truth_surfaces": affected_truth_surfaces,
        "read_first": read_first,
        "truth_impact_lane_counts": truth_lane_counts,
        "cross_repo_dependencies": cross_repo_dependencies,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    parser.add_argument("--task-type")
    parser.add_argument("--output", default="generated/knowledge/task-context-report.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    payload = resolve_context(repo_root, args.range_spec, args.task_type)
    rendered = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    output_path = repo_root / args.output

    if args.check:
        if not output_path.exists():
            raise SystemExit(f"MISSING_FILE:{output_path}")
        if output_path.read_text() != rendered:
            raise SystemExit("TASK_CONTEXT_REPORT_DRIFT")
    else:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(rendered)

    print(rendered, end="")


if __name__ == "__main__":
    main()
