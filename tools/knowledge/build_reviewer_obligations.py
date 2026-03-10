#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path
from typing import Any

import jsonschema


DEFAULT_OUTPUT = Path("generated/knowledge/reviewer-obligations.json")
SCHEMA_PATH = Path("docs/meta/knowledge/schemas/reviewer-obligations.schema.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 12 reviewer obligations.")
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
            raise SystemExit(f"Reviewer obligations drift detected: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def build_payload(review_decision: dict[str, Any], skill_registry: dict[str, Any]) -> dict[str, Any]:
    selected = set(review_decision["decision"]["selected_skills"])
    skill_index = {skill["skill_id"]: skill for skill in skill_registry["skills"]}

    reviewer_to_skills: dict[str, list[str]] = defaultdict(list)
    for skill_id in selected:
        for reviewer in skill_index[skill_id]["required_reviewers"]:
            reviewer_to_skills[reviewer].append(skill_id)

    justifications = []
    for reviewer in sorted(reviewer_to_skills):
        required_by = sorted(reviewer_to_skills[reviewer])
        reason = (
            f"{reviewer} is required because "
            + ", ".join(required_by)
            + " selects this reviewer in the canonical skill registry"
        )
        justifications.append(
            {
                "reviewer": reviewer,
                "required_by_skills": required_by,
                "reason": reason,
                "blocking": review_decision["decision"]["severity"] in {"high", "release-critical"},
            }
        )

    escalation = []
    if review_decision["decision"]["severity"] in {"high", "release-critical"}:
        escalation = sorted(review_decision["required_reviewers"])

    return {
        "pack_id": "reviewer-obligations",
        "generated_by": "tools/knowledge/build_reviewer_obligations.py",
        "source_range": review_decision["source_range"],
        "canonical_inputs": sorted(
            {
                "generated/knowledge/review-decision.json",
                "generated/skills/skill-registry.json",
                "docs/meta/knowledge/DECISION_RUNTIME_MODEL.md",
            }
        ),
        "schema_version": 1,
        "diff_range": review_decision["diff_range"],
        "required_reviewer_groups": sorted(review_decision["required_reviewers"]),
        "escalation_reviewers": escalation,
        "optional_reviewers": [],
        "reviewer_justifications": justifications,
    }


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    schema = load_json(repo_root / SCHEMA_PATH)
    review_decision = load_json(repo_root / "generated/knowledge/review-decision.json")
    skill_registry = load_json(repo_root / "generated/skills/skill-registry.json")
    payload = build_payload(review_decision, skill_registry)
    jsonschema.validate(instance=payload, schema=schema)
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    write_or_check(output_path, serialized, args.check)
    mode = "check" if args.check else "write"
    print(
        "REVIEWER_OBLIGATIONS_OK "
        f"mode={mode} required={','.join(payload['required_reviewer_groups'])}"
    )


if __name__ == "__main__":
    main()
