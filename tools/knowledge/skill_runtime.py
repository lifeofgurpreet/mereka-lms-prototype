#!/usr/bin/env python3
"""Shared runtime primitives for Wave 7 task resolution and bundle generation."""

from __future__ import annotations

import fnmatch
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

LEGACY_DETAILED_REFERENCE_SURFACES = {
    "docs/concepts/architecture/ARCHITECTURE_CHARTER.md",
    "docs/concepts/architecture/AUTHORIZATION_MODEL.md",
    "docs/concepts/architecture/CONTROL_PLANES.md",
    "docs/concepts/architecture/DATA_GOVERNANCE.md",
    "docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md",
    "docs/concepts/architecture/README.md",
    "docs/concepts/architecture/TENANT_LIFECYCLE.md",
    "docs/concepts/architecture/TENANT_OPERATING_SYSTEM.md",
    "docs/concepts/architecture/TUTOR_AND_EXTENSION_MODEL.md",
    "docs/concepts/architecture/multi-tenancy-overview.md",
    "docs/concepts/architecture/notification-pipeline-overview.md",
    "docs/concepts/architecture/proctoring-architecture-overview.md",
    "docs/concepts/architecture/content-libraries-overview.md",
    "docs/concepts/architecture/enterprise-services-overview.md",
    "docs/concepts/architecture/purchase-gateway-overview.md",
}


def load_yaml(path: Path) -> dict[str, Any]:
    return yaml.safe_load(path.read_text())


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def changed_files(repo_root: Path, range_spec: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=ACMR", range_spec],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def is_canonical_surface(repo_root: Path, surface: str) -> bool:
    if not (repo_root / surface).exists():
        return False
    return not (
        surface.startswith("docs/archive/")
        or surface.startswith("specs/archive/")
        or surface in LEGACY_DETAILED_REFERENCE_SURFACES
    )


def load_runtime_inputs(repo_root: Path) -> dict[str, Any]:
    return {
        "taxonomy": load_yaml(repo_root / "docs" / "meta" / "skills" / "TASK_TYPE_TAXONOMY.yaml"),
        "bundle_rules": load_yaml(repo_root / "docs" / "meta" / "skills" / "SKILL_BUNDLE_RULES.yaml"),
        "release_obligations": load_yaml(repo_root / "docs" / "meta" / "contracts" / "RELEASE_OBLIGATIONS.yaml"),
        "change_manifest": load_json(repo_root / "generated" / "knowledge" / "change-manifest.json"),
        "truth_impact": load_json(repo_root / "generated" / "knowledge" / "truth-impact-report.json"),
        "wrapper_report": load_json(repo_root / "generated" / "knowledge" / "wrapper-retirement-report.json"),
        "cross_repo_manifest": load_json(repo_root / "generated" / "contracts" / "cross-repo-manifest.json"),
        "deployment_impact": load_json(repo_root / "generated" / "contracts" / "deployment-impact-report.json"),
        "knowledge_catalog": load_json(repo_root / "generated" / "catalogs" / "knowledge-catalog.json"),
        "service_contracts": {
            path.stem: load_yaml(path)
            for path in sorted((repo_root / "deploy" / "contracts" / "service-contracts").glob("*.yaml"))
        },
    }


def match_patterns(rel_path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(rel_path, pattern) for pattern in patterns)


def explicit_wrapper_paths(taxonomy: dict[str, Any]) -> set[str]:
    return set(taxonomy["task_types"]["compatibility_or_wrapper_cleanup"].get("explicit_paths", []))


def classify_task_candidates(rel_path: str, runtime: dict[str, Any], entry: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    taxonomy = runtime["taxonomy"]
    wrappers = explicit_wrapper_paths(taxonomy)
    candidates: list[dict[str, Any]] = []
    for task_type in taxonomy["task_resolution_order"]:
        rule = taxonomy["task_types"][task_type]
        score = 0
        reasons: list[str] = []
        if rel_path in wrappers and task_type == "compatibility_or_wrapper_cleanup":
            score += 5
            reasons.append("explicit wrapper path")
        if match_patterns(rel_path, rule.get("trigger_patterns", [])):
            score += 4
            reasons.append("trigger pattern match")
        if match_patterns(rel_path, rule.get("excludes", [])):
            score = 0
            reasons = []
        if entry:
            lane_token = f"{entry.get('root')}:{entry.get('lane')}" if entry.get("root") in {"docs", "specs"} else ""
            if lane_token and lane_token in rule.get("primary_signal_lanes", []):
                score += 3
                reasons.append(f"lane match {lane_token}")
            if entry.get("change_class") in rule.get("primary_signal_change_classes", []):
                score += 2
                reasons.append(f"change class {entry.get('change_class')}")
        if score:
            candidates.append({"task_type": task_type, "score": score, "why": reasons})
    if not candidates:
        candidates.append({"task_type": "generated_surface_refresh", "score": 1, "why": ["fallback generated-surface classification"]})
    candidates.sort(key=lambda item: (-item["score"], taxonomy["task_resolution_order"].index(item["task_type"])))
    return candidates


def bundle_read_first(repo_root: Path, runtime: dict[str, Any], task_type: str) -> list[dict[str, Any]]:
    return [
        item
        for item in runtime["bundle_rules"]["seeded_read_first_surfaces"][task_type]
        if is_canonical_surface(repo_root, item["path"])
    ]


def aggregate_commands(runtime: dict[str, Any], task_type: str) -> list[str]:
    commands = list(runtime["bundle_rules"]["default_command_families"]["baseline"])
    if task_type in {"normative_spec_change", "proposal_or_rfc_change"}:
        commands.extend(runtime["bundle_rules"]["default_command_families"]["spec_truth"])
    commands.extend(runtime["bundle_rules"]["default_command_families"]["task_runtime"])
    deduped: list[str] = []
    for cmd in commands:
        if cmd not in deduped:
            deduped.append(cmd)
    return deduped


def aggregate_reviewers_and_evidence(runtime: dict[str, Any], task_type: str, matched_entries: list[dict[str, Any]], touched_services: list[str]) -> tuple[list[str], list[str]]:
    reviewers = {
        reviewer
        for entry in matched_entries
        for reviewer in entry.get("review", {}).get("required_reviewers", [])
    }
    evidence = {
        key
        for entry in matched_entries
        for key, value in (entry.get("evidence") or {}).items()
        if value not in (False, None)
    }
    if task_type in {"cross_repo_contract_change", "release_or_runtime_change"}:
        deployment_index = {item["service"]: item for item in runtime["deployment_impact"].get("deployment_impacts", [])}
        for service in touched_services:
            reviewers.update(deployment_index.get(service, {}).get("required_reviewers", []))
            contract = runtime["service_contracts"].get(service)
            if contract:
                for change_class in contract.get("change_classes", []):
                    evidence.update(runtime["release_obligations"].get("required_evidence", {}).get(change_class, []))
        reviewers.update(runtime["deployment_impact"].get("required_reviewers", []))
        evidence.update({"release_obligations", "reviewer_bundle", "truth_impact_report"})
    return sorted(reviewers), sorted(evidence)


def confidence_for_candidates(candidates: list[dict[str, Any]]) -> tuple[str, str]:
    if len(candidates) == 1:
        return "high", "single clear task-type match"
    top = candidates[0]
    runner_up = candidates[1]
    gap = top["score"] - runner_up["score"]
    if gap >= 3:
        return "high", f"{top['task_type']} leads by score gap {gap}"
    if gap >= 1:
        return "medium", f"{top['task_type']} leads but secondary task remains plausible"
    return "low", "top candidates are effectively tied and need human judgment"
