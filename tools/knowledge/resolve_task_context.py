#!/usr/bin/env python3
"""Resolve a diff range or explicit task type into Wave 7 task runtime context."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
import sys

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.task_runtime import (
    OUT_OF_SCOPE_BY_TASK,
    build_entry_index,
    changed_files,
    escalation_conditions,
    infer_task_types_for_path,
    load_task_runtime_inputs,
    service_review_groups,
)


def required_commands(task_type: str, rules: dict) -> list[str]:
    commands = list(rules["required_command_sets"]["baseline"])
    if task_type in {"normative_spec_change", "proposal_or_rfc_change"}:
        commands.extend(rules["required_command_sets"]["spec_truth"])
    if task_type in {"cross_repo_contract_change", "release_or_runtime_change"}:
        commands.extend(rules["required_command_sets"]["contract_truth"])
    commands.extend(rules["required_command_sets"]["task_runtime"])
    return commands


def resolve_context(repo_root: Path, range_spec: str, explicit_task_type: str | None = None) -> dict:
    runtime = load_task_runtime_inputs(repo_root)
    taxonomy = runtime["taxonomy"]
    bundle_rules = runtime["bundle_rules"]
    release_obligations = runtime["release_obligations"]
    change_manifest = runtime["change_manifest"]
    truth_impact = runtime["truth_impact"]
    cross_repo_manifest = runtime["cross_repo_manifest"]
    deployment_impact = runtime["deployment_impact"]
    service_contracts = runtime["service_contracts"]
    changed = changed_files(repo_root, range_spec)
    entry_index = build_entry_index(change_manifest)
    service_review_index = service_review_groups(cross_repo_manifest)

    candidate_counts: Counter[str] = Counter()
    file_candidates: dict[str, list[str]] = {}
    for rel_path in changed:
        candidates = infer_task_types_for_path(rel_path, taxonomy)
        file_candidates[rel_path] = candidates
        candidate_counts.update(candidates)

    ordered = taxonomy["task_resolution_order"]
    resolved = explicit_task_type
    if not resolved:
        resolved = next((task for task in ordered if candidate_counts.get(task)), ordered[-1])

    matched_paths = [path for path, tasks in file_candidates.items() if resolved in tasks]
    if not matched_paths:
        matched_paths = changed

    matched_entries = [entry_index[path] for path in matched_paths if path in entry_index]
    impacted_surfaces = sorted(
        {
            surface
            for entry in matched_entries
            for surface in entry.get("impacted_truth_surfaces", [])
        }
    )

    reviewers = sorted(
        {
            reviewer
            for entry in matched_entries
            for reviewer in entry.get("review", {}).get("required_reviewers", [])
        }
    )
    evidence = sorted(
        {
            key
            for entry in matched_entries
            for key, value in (entry.get("evidence") or {}).items()
            if value not in (False, None)
        }
    )

    touched_services = sorted(
        {
            service
            for manifest_entry in cross_repo_manifest.get("entries", [])
            if manifest_entry["path"] in matched_paths
            for service in manifest_entry.get("touched_services", [])
        }
    )
    likely_cross_repo_dependencies = []
    deployment_index = {
        item["service"]: item for item in deployment_impact.get("deployment_impacts", [])
    }
    for service in touched_services:
        impact = deployment_index.get(service, {})
        likely_cross_repo_dependencies.append(
            {
                "service": service,
                "review_groups": impact.get("required_reviewers", service_review_index.get(service, [])),
                "overall_verdict": impact.get("cross_repo_verdict", cross_repo_manifest.get("overall_verdict")),
            }
        )

    if resolved in {"cross_repo_contract_change", "release_or_runtime_change"}:
        reviewers = sorted(
            set(reviewers)
            | {
                reviewer
                for item in likely_cross_repo_dependencies
                for reviewer in item["review_groups"]
            }
            | set(deployment_impact.get("required_reviewers", []))
        )

    if resolved in {"cross_repo_contract_change", "release_or_runtime_change"}:
        evidence = set(evidence)
        for service in touched_services:
            contract = service_contracts.get(service)
            if not contract:
                continue
            for change_class in contract.get("change_classes", []):
                evidence.update(release_obligations.get("required_evidence", {}).get(change_class, []))
        evidence.update({"release_obligations", "reviewer_bundle", "truth_impact_report"})
        evidence = sorted(evidence)

    context = {
        "generated_by": "tools/knowledge/resolve_task_context.py",
        "range": range_spec,
        "task_type": resolved,
        "one_line_intent": taxonomy["task_types"][resolved]["one_line_intent"],
        "authority_order": bundle_rules["authority_order"],
        "candidate_task_types": [
            {"task_type": task_type, "matched_files": candidate_counts.get(task_type, 0)}
            for task_type in ordered
            if candidate_counts.get(task_type)
        ],
        "matched_paths": matched_paths,
        "read_first": bundle_rules["canonical_read_first_defaults"][resolved],
        "generated_surfaces_to_refresh": bundle_rules["required_generated_surfaces"]
        + bundle_rules.get("conditional_generated_surfaces", {}).get(resolved, []),
        "affected_truth_surfaces": impacted_surfaces,
        "required_reviewers": reviewers,
        "required_evidence": evidence,
        "required_commands": required_commands(resolved, bundle_rules),
        "likely_cross_repo_dependencies": likely_cross_repo_dependencies,
        "out_of_scope": OUT_OF_SCOPE_BY_TASK[resolved],
        "escalation_conditions": escalation_conditions(resolved, cross_repo_manifest, taxonomy),
        "per_path_candidates": file_candidates,
        "truth_impact_lane_counts": truth_impact.get("impacted_lane_counts", {}),
    }
    return context


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    parser.add_argument("--task-type")
    parser.add_argument("--output")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    context = resolve_context(repo_root, args.range_spec, args.task_type)
    rendered = json.dumps(context, indent=2, sort_keys=True) + "\n"
    if args.output:
        output_path = repo_root / args.output
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(rendered)
    print(rendered, end="")


if __name__ == "__main__":
    main()
