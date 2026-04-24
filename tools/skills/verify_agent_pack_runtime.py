#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


HIGH_RISK_CATEGORIES = {"review", "release", "contracts", "cross-repo-impact"}
FORBIDDEN_PREFIXES = (
    "docs/archive/",
    "docs/operations/",
    "reports/",
    "evidence/",
    "specs/archive/",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify Wave 11 agent pack runtime semantics.")
    parser.add_argument("--repo-root", default=".")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()

    pack_registry = load_json(repo_root / "generated/skills/pack-registry.json")
    skill_registry = load_json(repo_root / "generated/skills/skill-registry.json")
    command_registry = load_json(repo_root / "generated/skills/command-registry.json")
    scenario_packs = load_json(repo_root / "generated/skills/scenario-packs.json")
    read_first = load_json(repo_root / "generated/skills/read-first.json")
    evidence_map = load_json(repo_root / "generated/skills/evidence-sufficiency-map.json")
    mixed_diff = load_json(repo_root / "generated/skills/mixed-diff-arbitration.json")
    runtime_convergence = load_json(repo_root / "generated/skills/runtime-convergence-report.json")

    pack_ids = {pack_registry["pack_id"], *(pack["pack_id"] for pack in pack_registry["packs"])}
    command_ids = {command["command_id"] for command in command_registry["commands"]}
    skill_ids = {skill["skill_id"] for skill in skill_registry["skills"]}
    evidence_classes = {entry["evidence_class"] for entry in evidence_map["evidence_classes"]}
    scenario_skill_ids = {skill_id for scenario in scenario_packs["scenarios"] for skill_id in scenario["required_skills"]}

    required_pack_ids = {
        "skill-registry",
        "command-registry",
        "scenario-packs",
        "skill-dependency-graph",
        "read-first",
        "pack-registry",
        "runtime-convergence-report",
        "evidence-sufficiency-map",
        "mixed-diff-arbitration",
    }
    ensure(required_pack_ids.issubset(pack_ids), f"Missing required packs: {sorted(required_pack_ids - pack_ids)}")

    for pack in pack_registry["packs"]:
        canonical_path = repo_root / pack["canonical_path"]
        schema_path = repo_root / pack["schema_path"]
        ensure(canonical_path.exists(), f"Registered pack path missing: {pack['pack_id']} -> {pack['canonical_path']}")
        ensure(schema_path.exists(), f"Registered pack schema missing: {pack['pack_id']} -> {pack['schema_path']}")
        ensure("/home/gurpreet" not in pack["canonical_path"], f"Absolute path leaked in pack registry: {pack['pack_id']}")
        ensure("/home/gurpreet" not in pack["schema_path"], f"Absolute schema path leaked in pack registry: {pack['pack_id']}")
        for projection_path in pack["projection_paths"]:
            ensure((repo_root / projection_path).exists(), f"Projection path missing: {pack['pack_id']} -> {projection_path}")
            ensure("/home/gurpreet" not in projection_path, f"Absolute projection path leaked: {pack['pack_id']}")
        for canonical_input in pack["canonical_inputs"]:
            ensure("/home/gurpreet" not in canonical_input, f"Absolute canonical input leaked: {pack['pack_id']}")
            ensure(not canonical_input.startswith(FORBIDDEN_PREFIXES), f"Forbidden canonical input in pack registry: {pack['pack_id']} -> {canonical_input}")

    read_first_md = (repo_root / "generated/skills/read-first.md").read_text()
    for entry in read_first["entries"]:
        ensure(entry["path"] in read_first_md, f"Read-first markdown drifted from canonical JSON: {entry['path']}")

    for skill in skill_registry["skills"]:
        ensure(skill["skill_id"] == skill["id"], f"Skill id mismatch: {skill['id']}")
        for pack_id in skill["pack_dependencies"]:
            ensure(pack_id in pack_ids, f"Skill references missing pack: {skill['skill_id']} -> {pack_id}")
        for command_id in skill["command_dependencies"]:
            ensure(command_id in command_ids, f"Skill references missing command: {skill['skill_id']} -> {command_id}")
        for source in skill["stable_inputs"]:
            ensure(not source["path"].startswith(FORBIDDEN_PREFIXES), f"Forbidden stable input path: {skill['skill_id']} -> {source['path']}")
        if skill["category"] in HIGH_RISK_CATEGORIES:
            ensure(skill["reviewer_rules"]["required_reviewers"], f"High-risk skill missing reviewer rules: {skill['skill_id']}")
            ensure(skill["evidence_rules"]["required_evidence_classes"], f"High-risk skill missing evidence rules: {skill['skill_id']}")
            ensure(skill["escalation_rules"]["manual_review_required"] is True, f"High-risk skill must require manual review: {skill['skill_id']}")

    for skill_id in scenario_skill_ids:
        ensure(skill_id in skill_ids, f"Scenario references unknown skill: {skill_id}")

    for evidence_class in evidence_classes:
        ensure(
            any(evidence_class in skill["required_evidence_classes"] for skill in skill_registry["skills"]),
            f"Evidence class has no backing skill: {evidence_class}",
        )

    covered_categories = set(mixed_diff["covered_categories"])
    actual_categories = {skill["category"] for skill in skill_registry["skills"]}
    ensure(actual_categories.issubset(covered_categories), "Mixed-diff arbitration does not cover all skill categories")
    for rule in mixed_diff["rules"]:
        ensure(rule["primary_read_first_skill"] in skill_ids, f"Mixed-diff rule references unknown skill: {rule['rule_id']}")

    failing_checks = [check for check in runtime_convergence["checks"] if check["status"] == "fail"]
    ensure(not failing_checks, f"Runtime convergence contradictions detected: {[check['check_id'] for check in failing_checks]}")

    print(
        "AGENT_PACK_RUNTIME_OK "
        f"packs={len(pack_ids)} skills={len(skill_ids)} evidence_classes={len(evidence_classes)} "
        f"mixed_diff_rules={len(mixed_diff['rules'])} convergence_failures={len(failing_checks)}"
    )


if __name__ == "__main__":
    main()
