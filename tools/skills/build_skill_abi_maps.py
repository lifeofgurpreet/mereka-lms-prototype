#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path
from typing import Any


DEFAULT_EVIDENCE_OUTPUT = Path("generated/skills/evidence-sufficiency-map.json")
DEFAULT_ARBITRATION_OUTPUT = Path("generated/skills/mixed-diff-arbitration.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 11 skill ABI support maps.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--evidence-output", default=str(DEFAULT_EVIDENCE_OUTPUT))
    parser.add_argument("--arbitration-output", default=str(DEFAULT_ARBITRATION_OUTPUT))
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def write_or_check(path: Path, payload: dict[str, Any], check: bool, label: str) -> None:
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if check:
        if not path.exists():
            raise FileNotFoundError(f"Missing output: {path}")
        if path.read_text() != serialized:
            raise SystemExit(f"{label} drift detected: {path}")
        print(f"{label}_OK mode=check")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(serialized)
    print(f"{label}_OK mode=write")


def build_evidence_map(skill_registry: dict[str, Any]) -> dict[str, Any]:
    evidence_to_skills: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for skill in skill_registry["skills"]:
        for evidence_class in skill["required_evidence_classes"]:
            evidence_to_skills[evidence_class].append(skill)

    evidence_classes = []
    for evidence_class in sorted(evidence_to_skills):
        skills = evidence_to_skills[evidence_class]
        reviewers = sorted({reviewer for skill in skills for reviewer in skill["required_reviewers"]})
        evidence_classes.append(
            {
                "evidence_class": evidence_class,
                "required_for_skills": sorted(skill["skill_id"] for skill in skills),
                "required_reviewers": reviewers,
                "sufficiency_policy": "all-required-reviewers-must-confirm-or-explicitly-delegate",
                "escalation_if_missing": [
                    "block merge or promotion",
                    "route to highest-risk reviewer set"
                ]
            }
        )

    return {
        "pack_id": "evidence-sufficiency-map",
        "generated_by": "tools/skills/build_skill_abi_maps.py",
        "source_range": None,
        "canonical_inputs": [
            "generated/skills/skill-registry.json"
        ],
        "schema_version": 1,
        "evidence_classes": evidence_classes
    }


def build_arbitration_map(skill_registry: dict[str, Any]) -> dict[str, Any]:
    category_to_skills: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for skill in skill_registry["skills"]:
        category_to_skills[skill["category"]].append(skill)

    rules = [
        {
            "rule_id": "contracts-release",
            "when_categories": ["contracts", "release"],
            "reviewer_merge_strategy": "union-reviewers-prioritize-platform-and-release",
            "evidence_merge_strategy": "union-evidence-classes",
            "primary_read_first_skill": "cross-repo-release-contract-review",
            "manual_arbitration_trigger": ["workflow-and-contract-disagree", "service-identity-ambiguous"]
        },
        {
            "rule_id": "documentation-cross-repo-impact",
            "when_categories": ["documentation-truth", "cross-repo-impact"],
            "reviewer_merge_strategy": "union-reviewers-prioritize-docs-then-platform",
            "evidence_merge_strategy": "union-evidence-classes",
            "primary_read_first_skill": "change-impact-triage",
            "manual_arbitration_trigger": ["canonical-owner-unclear", "docs-vs-contract-conflict"]
        },
        {
            "rule_id": "operations-release",
            "when_categories": ["operations", "release"],
            "reviewer_merge_strategy": "union-reviewers-prioritize-ops-and-release",
            "evidence_merge_strategy": "union-evidence-classes",
            "primary_read_first_skill": "runbook-evidence-triage",
            "manual_arbitration_trigger": ["evidence-insufficient", "rollback-path-unclear"]
        },
        {
            "rule_id": "topology-contracts",
            "when_categories": ["topology", "contracts"],
            "reviewer_merge_strategy": "union-reviewers-prioritize-platform",
            "evidence_merge_strategy": "union-evidence-classes",
            "primary_read_first_skill": "topology-lookup",
            "manual_arbitration_trigger": ["alias-or-domain-registry-conflict"]
        }
    ]

    return {
        "pack_id": "mixed-diff-arbitration",
        "generated_by": "tools/skills/build_skill_abi_maps.py",
        "source_range": None,
        "canonical_inputs": [
            "generated/skills/skill-registry.json",
            "generated/skills/scenario-packs.json"
        ],
        "schema_version": 1,
        "rules": rules,
        "covered_categories": sorted(category_to_skills)
    }


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    skill_registry = load_json(repo_root / "generated/skills/skill-registry.json")
    evidence_payload = build_evidence_map(skill_registry)
    arbitration_payload = build_arbitration_map(skill_registry)
    write_or_check(Path(args.evidence_output), evidence_payload, args.check, "EVIDENCE_SUFFICIENCY_MAP")
    write_or_check(Path(args.arbitration_output), arbitration_payload, args.check, "MIXED_DIFF_ARBITRATION")


if __name__ == "__main__":
    main()
