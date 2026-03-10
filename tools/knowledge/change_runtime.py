#!/usr/bin/env python3
"""Shared Wave 5 change-intelligence helpers."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.knowledge_model import classify_path, to_json_value


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text()) or {}
    return data if isinstance(data, dict) else {}


def load_wave5_schema(repo_root: Path, name: str) -> dict:
    return load_yaml(repo_root / "docs" / "meta" / "knowledge" / name)


def changed_files(repo_root: Path, range_spec: str) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(repo_root), "diff", "--name-only", range_spec],
        capture_output=True,
        text=True,
        check=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def classify_change_class(entry: dict) -> str:
    root = entry.get("root")
    lane = entry.get("lane")
    classification = entry.get("classification")
    path = str(entry.get("path", ""))

    if classification == "compatibility":
        return "compatibility_wrapper_update"
    if classification == "generated":
        return "generated_surface_refresh"
    if path == ".github/workflows/docs-policy.yml":
        return "docs_support_change"
    if path in {
        "scripts/qa/run-knowledge-runtime-gates.sh",
        "scripts/qa/run-knowledge-integrity-gates.sh",
    }:
        return "docs_support_change"
    if path.startswith("tools/knowledge/"):
        return "docs_support_change"
    if lane == "evidence":
        return "evidence_only_change"
    if lane == "archive":
        return "archival_only_change"
    if lane == "review" and any(token in path for token in ("HANDOFF", "CHECKLIST", "CLOSEOUT")):
        return "reviewer_handoff_only"
    if root == "specs" and lane == "normative" and classification == "canonical":
        return "normative_contract_change"
    if root == "specs" and lane == "proposal":
        return "proposal_only"
    if root == "specs" and lane in {"plan", "testplan"}:
        return "plan_only"
    if root == "docs" and lane in {"concept", "runbook", "review", "adr", "index", "other"}:
        return "docs_support_change"
    return "generated_surface_refresh"


def reviewer_assignment(entry: dict, ownership_map: dict, change_class: str, review_rules: dict) -> dict:
    path = str(entry["path"])
    lane_key = f"{entry['root']}:{entry['lane']}"
    lane_rule = (ownership_map.get("lanes") or {}).get(lane_key, {})
    owner_team = lane_rule.get("owner_team", "")
    reviewer_roles = list(lane_rule.get("reviewer_roles") or [])

    for override in ownership_map.get("surface_overrides") or []:
        if override.get("path") == path:
            owner_team = override.get("owner_team", owner_team)
            reviewer_roles = list(override.get("reviewer_roles") or reviewer_roles)

    class_rule = (review_rules.get("review_rules") or {}).get(change_class, {})
    required = list(class_rule.get("required_reviewers") or [])
    optional = list(class_rule.get("optional_reviewers") or [])
    for override in review_rules.get("surface_specific_rules") or []:
        prefix = override.get("path_prefix")
        if prefix and path.startswith(prefix):
            required = list(override.get("required_reviewers") or required)

    return {
        "owner_team": owner_team,
        "lane_reviewer_roles": reviewer_roles,
        "required_reviewers": required,
        "optional_reviewers": optional,
        "block_merge_without_all_required": bool(class_rule.get("block_merge_without_all_required", False)),
    }


def evidence_requirements(change_class: str, evidence_rules: dict) -> dict:
    return dict((evidence_rules.get("obligations") or {}).get(change_class, {}))


def impacted_truth_surfaces(entry: dict) -> list[str]:
    path = str(entry["path"])
    root = entry.get("root")
    lane = entry.get("lane")
    touched = [path]

    if root == "specs":
        base = path.rsplit("/", 1)[-1].replace("_spec.md", "").replace("_plan.md", "").replace("_testplan.md", "")
        if lane in {"normative", "proposal"}:
            touched.extend(
                [
                    f"specs/plans/{base}_plan.md",
                    f"specs/plans/{base}_testplan.md",
                ]
            )
        if lane in {"plan", "testplan"}:
            touched.append(f"specs/{base}_spec.md")
    if root == "docs" and lane in {"adr", "runbook", "concept", "review"}:
        touched.extend(["docs/catalog.json", "generated/catalogs/knowledge-catalog.json"])
    if path == ".github/workflows/docs-policy.yml" or path.startswith("scripts/qa/run-knowledge-") or path.startswith(
        "tools/knowledge/"
    ):
        touched.extend(
            [
                "generated/knowledge/change-manifest.json",
                "generated/knowledge/review-bundle.md",
                "generated/knowledge/truth-impact-report.json",
                "generated/knowledge/wrapper-retirement-report.json",
                "generated/catalogs/knowledge-catalog.json",
                "generated/graphs/knowledge-graph.json",
            ]
        )
    if entry.get("classification") in {"compatibility", "generated"}:
        touched.extend(["generated/catalogs/knowledge-catalog.json", "generated/graphs/knowledge-graph.json"])

    deduped = []
    seen = set()
    for item in touched:
        if item not in seen:
            seen.add(item)
            deduped.append(item)
    return deduped


def build_changed_entry(repo_root: Path, rel_path: str, ownership_map: dict, change_classes: dict, evidence_rules: dict, review_rules: dict) -> dict:
    path = repo_root / rel_path
    if path.exists():
        entry = classify_path(path, repo_root)
    else:
        entry = {
            "path": rel_path,
            "root": "other",
            "lane": "other",
            "classification": "supporting",
            "status": "",
            "owner": "",
            "title": Path(rel_path).name,
        }
    change_class = classify_change_class(entry)
    change_spec = (change_classes.get("change_classes") or {}).get(change_class, {})
    assignment = reviewer_assignment(entry, ownership_map, change_class, review_rules)
    evidence = evidence_requirements(change_class, evidence_rules)

    return to_json_value(
        {
            **entry,
            "change_class": change_class,
            "change_risk": change_spec.get("risk", "low"),
            "description": change_spec.get("description", ""),
            "impacted_truth_surfaces": impacted_truth_surfaces(entry),
            "review": assignment,
            "evidence": evidence,
        }
    )


def load_runtime_inputs(repo_root: Path) -> dict:
    return {
        "ownership_map": load_wave5_schema(repo_root, "OWNERSHIP_MAP.yaml"),
        "change_classes": load_wave5_schema(repo_root, "CHANGE_CLASSES.yaml"),
        "evidence_rules": load_wave5_schema(repo_root, "EVIDENCE_OBLIGATIONS.yaml"),
        "review_rules": load_wave5_schema(repo_root, "REVIEW_RULES.yaml"),
    }
