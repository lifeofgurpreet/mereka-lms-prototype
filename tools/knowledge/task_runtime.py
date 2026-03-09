#!/usr/bin/env python3
"""Helpers for the Wave 7 task runtime."""

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


def load_yaml(path: Path) -> dict[str, Any]:
    return yaml.safe_load(path.read_text())


def changed_files(repo_root: Path, range_spec: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=ACMR", range_spec],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def load_task_runtime_inputs(repo_root: Path) -> dict[str, Any]:
    return {
        "taxonomy": load_yaml(repo_root / "docs" / "meta" / "skills" / "TASK_TYPE_TAXONOMY.yaml"),
        "bundle_rules": load_yaml(repo_root / "docs" / "meta" / "skills" / "SKILL_BUNDLE_RULES.yaml"),
        "release_obligations": load_yaml(repo_root / "docs" / "meta" / "contracts" / "RELEASE_OBLIGATIONS.yaml"),
        "change_manifest": load_json(repo_root / "generated" / "knowledge" / "change-manifest.json"),
        "truth_impact": load_json(repo_root / "generated" / "knowledge" / "truth-impact-report.json"),
        "cross_repo_manifest": load_json(repo_root / "generated" / "contracts" / "cross-repo-manifest.json"),
        "deployment_impact": load_json(repo_root / "generated" / "contracts" / "deployment-impact-report.json"),
        "service_contracts": {
            path.stem: load_yaml(path)
            for path in sorted((repo_root / "deploy" / "contracts" / "service-contracts").glob("*.yaml"))
        },
    }


def match_patterns(rel_path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(rel_path, pattern) for pattern in patterns)


def infer_task_types_for_path(rel_path: str, taxonomy: dict[str, Any]) -> list[str]:
    task_types = taxonomy["task_types"]
    matches: list[str] = []
    for task_type in taxonomy["task_resolution_order"]:
        rule = task_types[task_type]
        includes = rule.get("trigger_patterns", [])
        excludes = rule.get("excludes", [])
        if includes and not match_patterns(rel_path, includes):
            continue
        if excludes and match_patterns(rel_path, excludes):
            continue
        matches.append(task_type)
    if not matches:
        matches.append("review_handoff_or_generated_surface_refresh")
    return matches


def build_entry_index(change_manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {entry["path"]: entry for entry in change_manifest.get("entries", [])}


def service_review_groups(cross_repo_manifest: dict[str, Any]) -> dict[str, list[str]]:
    return {
        item["service"]: item.get("review_groups", [])
        for item in cross_repo_manifest.get("services", [])
    }


OUT_OF_SCOPE_BY_TASK = {
    "normative_spec_change": [
        "proposal-lane reshaping without contract change",
        "cross-repo deployment realization unless the task also changes contracts",
        "generated-surface-only cleanup",
    ],
    "proposal_or_rfc_change": [
        "normative contract edits in root specs",
        "runtime rollout or release obligations",
        "retroactive ADR rewriting",
    ],
    "architecture_or_adr_change": [
        "mass runbook rewrites",
        "runtime-only fixes without decision changes",
        "generated artifact refresh without source-policy change",
    ],
    "cross_repo_contract_change": [
        "live-cluster reconciliation",
        "direct edits to bbi-infrastructure from this repo",
        "repo-local wording-only cleanup",
    ],
    "release_or_runtime_change": [
        "architecture history edits unless explicitly required",
        "new deployment topology debates",
        "wrapper-retirement work that does not block runtime truth",
    ],
    "runbook_or_ops_change": [
        "normative product contract changes",
        "GitOps topology redesign",
        "generated-surface-only refresh",
    ],
    "evidence_or_status_change": [
        "contract changes without corresponding source edits",
        "new reviewer policy invention",
        "runtime or infra behavior changes",
    ],
    "review_handoff_or_generated_surface_refresh": [
        "source-policy changes",
        "contract semantics changes",
        "normative spec edits",
    ],
}


def escalation_conditions(task_type: str, cross_repo_manifest: dict[str, Any], taxonomy: dict[str, Any]) -> list[str]:
    conditions: list[str] = []
    for sibling in taxonomy["task_types"][task_type].get("escalation_if_combined_with", []):
        if sibling != "none":
            conditions.append(f"mixed task overlaps with {sibling}")
    verdict = cross_repo_manifest.get("overall_verdict")
    if task_type in {"cross_repo_contract_change", "release_or_runtime_change"}:
        if verdict == "manual_review_required":
            conditions.append("cross-repo verdict is manual_review_required")
        if verdict == "unknown_mapping":
            conditions.append("cross-repo verdict is unknown_mapping")
    if task_type in {"architecture_or_adr_change", "normative_spec_change"}:
        conditions.append("human review required if architecture and runtime truth move together")
    return conditions
