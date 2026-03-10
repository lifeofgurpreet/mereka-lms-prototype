#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import jsonschema


DEFAULT_OUTPUT = Path("generated/knowledge/read-first-packs.json")
SCHEMA_PATH = Path("docs/meta/knowledge/schemas/read-first-packs.schema.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 12 read-first packs output.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def write_or_check(path: Path, content: str, check: bool) -> None:
    if check:
        if not path.exists():
            raise FileNotFoundError(f"Missing output: {path}")
        if path.read_text() != content:
            raise SystemExit(f"Read-first packs drift detected: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def priority_for_pack(pack_id: str, severity: str) -> str:
    if pack_id in {"pack-registry", "skill-registry", "runtime-convergence-report"}:
        return "high" if severity in {"high", "release-critical"} else "medium"
    if pack_id in {"evidence-sufficiency-map", "mixed-diff-arbitration"}:
        return "high" if severity in {"high", "release-critical"} else "medium"
    if pack_id == "read-first":
        return "medium"
    return "low"


def build_payload(
    review_decision: dict[str, Any],
    reviewer_obligations: dict[str, Any],
    evidence_obligations: dict[str, Any],
    pack_registry: dict[str, Any],
    skill_registry: dict[str, Any],
    arbitration_map: dict[str, Any],
) -> dict[str, Any]:
    severity = review_decision["decision"]["severity"]
    selected_skills = review_decision["decision"]["selected_skills"]
    skill_index = {skill["skill_id"]: skill for skill in skill_registry["skills"]}

    categories = {skill_index[skill_id]["category"] for skill_id in selected_skills}
    rules = []
    for rule in arbitration_map["rules"]:
        if set(rule["when_categories"]).issubset(categories):
            rules.append(rule)

    explicit = {
        item["pack_id"]: {
            "pack_id": item["pack_id"],
            "priority": priority_for_pack(item["pack_id"], severity),
            "reason": item["reason"],
            "source_skill": item.get("source_skill", selected_skills[0]),
        }
        for item in review_decision["read_first_packs"]
    }

    for rule in rules:
        primary_skill = rule["primary_read_first_skill"]
        for pack_id in skill_index[primary_skill]["pack_dependencies"]:
            explicit.setdefault(
                pack_id,
                {
                    "pack_id": pack_id,
                    "priority": priority_for_pack(pack_id, severity),
                    "reason": f"required by arbitration rule {rule['rule_id']}",
                    "source_skill": primary_skill,
                },
            )

    pack_order = ["pack-registry", "skill-registry", "runtime-convergence-report", "evidence-sufficiency-map", "mixed-diff-arbitration", "read-first"]
    ordered_packs = sorted(
        explicit.values(),
        key=lambda item: (
            {"high": 0, "medium": 1, "low": 2}[item["priority"]],
            pack_order.index(item["pack_id"]) if item["pack_id"] in pack_order else len(pack_order),
            item["pack_id"],
        ),
    )

    used_pack_ids = {item["pack_id"] for item in ordered_packs}
    skip_packs = []
    for pack in sorted(pack_registry["packs"], key=lambda item: item["pack_id"]):
        if pack["pack_id"] in used_pack_ids:
            continue
        skip_packs.append(
            {
                "pack_id": pack["pack_id"],
                "reason": "not required by selected skills or arbitration rules for this diff",
            }
        )

    priority_buckets = {
        "high_risk": [item["pack_id"] for item in ordered_packs if item["priority"] == "high"],
        "medium_risk": [item["pack_id"] for item in ordered_packs if item["priority"] == "medium"],
        "low_risk": [item["pack_id"] for item in ordered_packs if item["priority"] == "low"],
    }

    reviewer_merge_strategy = "union-reviewers"
    evidence_merge_strategy = "union-evidence-classes"
    if rules:
        reviewer_merge_strategy = rules[0]["reviewer_merge_strategy"]
        evidence_merge_strategy = rules[0]["evidence_merge_strategy"]

    blocking_release_checks = []
    if review_decision["decision"]["severity"] in {"high", "release-critical"}:
        if reviewer_obligations["required_reviewer_groups"]:
            blocking_release_checks.append("required-reviewer-groups-present")
        if evidence_obligations["obligations"]:
            blocking_release_checks.append("required-evidence-obligations-present")
        if review_decision["decision"]["runtime_convergence_state"] != "fail":
            blocking_release_checks.append("runtime-convergence-not-failing")

    return {
        "pack_id": "read-first-packs",
        "generated_by": "tools/knowledge/build_read_first_packs.py",
        "source_range": review_decision["source_range"],
        "canonical_inputs": sorted(
            {
                "generated/knowledge/review-decision.json",
                "generated/knowledge/reviewer-obligations.json",
                "generated/knowledge/evidence-obligations.json",
                "generated/skills/pack-registry.json",
                "generated/skills/skill-registry.json",
                "generated/skills/mixed-diff-arbitration.json",
                "docs/meta/knowledge/DECISION_RUNTIME_MODEL.md",
            }
        ),
        "schema_version": 1,
        "diff_range": review_decision["diff_range"],
        "priority_buckets": priority_buckets,
        "ordered_packs": ordered_packs,
        "skip_packs": skip_packs,
        "arbitration": {
            "applied_rules": [rule["rule_id"] for rule in rules],
            "reviewer_merge_strategy": reviewer_merge_strategy,
            "evidence_merge_strategy": evidence_merge_strategy,
            "primary_skill_order": [
                rule["primary_read_first_skill"] for rule in rules
            ] or selected_skills,
            "blocking_release_checks": blocking_release_checks,
        },
    }


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    schema = load_json(repo_root / SCHEMA_PATH)
    review_decision = load_json(repo_root / "generated/knowledge/review-decision.json")
    reviewer_obligations = load_json(repo_root / "generated/knowledge/reviewer-obligations.json")
    evidence_obligations = load_json(repo_root / "generated/knowledge/evidence-obligations.json")
    pack_registry = load_json(repo_root / "generated/skills/pack-registry.json")
    skill_registry = load_json(repo_root / "generated/skills/skill-registry.json")
    arbitration_map = load_json(repo_root / "generated/skills/mixed-diff-arbitration.json")

    payload = build_payload(
        review_decision,
        reviewer_obligations,
        evidence_obligations,
        pack_registry,
        skill_registry,
        arbitration_map,
    )
    jsonschema.validate(instance=payload, schema=schema)
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    write_or_check(output_path, serialized, args.check)
    mode = "check" if args.check else "write"
    print(
        "READ_FIRST_PACKS_OK "
        f"mode={mode} ordered={len(payload['ordered_packs'])} "
        f"rules={len(payload['arbitration']['applied_rules'])}"
    )


if __name__ == "__main__":
    main()
