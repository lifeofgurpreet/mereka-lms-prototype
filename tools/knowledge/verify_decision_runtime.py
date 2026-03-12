#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import jsonschema


OUTPUT_SCHEMA_MAP = {
    "generated/knowledge/review-decision.json": "docs/meta/knowledge/schemas/review-decision.schema.json",
    "generated/knowledge/reviewer-obligations.json": "docs/meta/knowledge/schemas/reviewer-obligations.schema.json",
    "generated/knowledge/evidence-obligations.json": "docs/meta/knowledge/schemas/evidence-obligations.schema.json",
    "generated/knowledge/read-first-packs.json": "docs/meta/knowledge/schemas/read-first-packs.schema.json",
    "generated/knowledge/release-readiness.json": "docs/meta/knowledge/schemas/release-readiness.schema.json",
    "generated/knowledge/runtime-evaluation.json": "docs/meta/knowledge/schemas/runtime-evaluation.schema.json",
}

HIGH_RISK_LEVELS = {"high", "release-critical"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify Wave 12 decision runtime outputs and semantics.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="diff_range", default="origin/main...HEAD")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def git_stdout(repo_root: Path, *args: str) -> str:
    import subprocess

    result = subprocess.run(
        ["git", "-C", str(repo_root), *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def canonicalize_diff_range(repo_root: Path, diff_range: str) -> str:
    current_head = git_stdout(repo_root, "rev-parse", "HEAD")
    if "..." in diff_range:
        left, right = diff_range.split("...", 1)
        merge_base = git_stdout(repo_root, "merge-base", left, right)
        resolved_right = git_stdout(repo_root, "rev-parse", right)
        canonical_right = "HEAD" if resolved_right == current_head else resolved_right
        return f"{merge_base}...{canonical_right}"
    if ".." in diff_range:
        left, right = diff_range.split("..", 1)
        resolved_left = git_stdout(repo_root, "rev-parse", left)
        resolved_right = git_stdout(repo_root, "rev-parse", right)
        canonical_right = "HEAD" if resolved_right == current_head else resolved_right
        return f"{resolved_left}..{canonical_right}"
    return git_stdout(repo_root, "rev-parse", diff_range)


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def validate_schemas(repo_root: Path) -> None:
    for output_rel, schema_rel in OUTPUT_SCHEMA_MAP.items():
        output_path = repo_root / output_rel
        schema_path = repo_root / schema_rel
        ensure(output_path.exists(), f"Missing decision-runtime output: {output_rel}")
        ensure(schema_path.exists(), f"Missing decision-runtime schema: {schema_rel}")
        payload = load_json(output_path)
        schema = load_json(schema_path)
        jsonschema.validate(instance=payload, schema=schema)


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    canonical_range = canonicalize_diff_range(repo_root, args.diff_range)

    validate_schemas(repo_root)

    review_decision = load_json(repo_root / "generated/knowledge/review-decision.json")
    reviewer_obligations = load_json(repo_root / "generated/knowledge/reviewer-obligations.json")
    evidence_obligations = load_json(repo_root / "generated/knowledge/evidence-obligations.json")
    read_first_packs = load_json(repo_root / "generated/knowledge/read-first-packs.json")
    release_readiness = load_json(repo_root / "generated/knowledge/release-readiness.json")
    runtime_evaluation = load_json(repo_root / "generated/knowledge/runtime-evaluation.json")
    pack_registry = load_json(repo_root / "generated/skills/pack-registry.json")
    skill_registry = load_json(repo_root / "generated/skills/skill-registry.json")

    skill_ids = {skill["skill_id"] for skill in skill_registry["skills"]}
    pack_ids = {pack_registry["pack_id"], *(pack["pack_id"] for pack in pack_registry["packs"])}

    ensure(review_decision["source_range"] == canonical_range, "Review decision diff range drift detected")
    ensure(release_readiness["source_range"] == canonical_range, "Release readiness diff range drift detected")
    ensure(review_decision["decision"]["selected_skills"], "Review decision selected no skills")
    for skill_id in review_decision["decision"]["selected_skills"]:
        ensure(skill_id in skill_ids, f"Review decision references unknown skill: {skill_id}")

    ensure(reviewer_obligations["required_reviewer_groups"] == review_decision["required_reviewers"], "Reviewer obligations drift from review decision")
    expected_missing_evidence = sorted(
        set(evidence_obligations["required_evidence_packs"])
        | set(evidence_obligations["required_status_updates"])
    )
    ensure(
        expected_missing_evidence == sorted(release_readiness["missing_evidence"]),
        "Release readiness missing_evidence drift from evidence obligations",
    )

    for pack in read_first_packs["ordered_packs"]:
        ensure(pack["pack_id"] in pack_ids, f"Read-first output references unknown pack: {pack['pack_id']}")

    for canonical_input in review_decision["canonical_inputs"]:
        ensure((repo_root / canonical_input).exists(), f"Review decision canonical input missing: {canonical_input}")
    for canonical_input in release_readiness["canonical_inputs"]:
        ensure((repo_root / canonical_input).exists(), f"Release readiness canonical input missing: {canonical_input}")

    ensure(release_readiness["why"], "Release readiness lacks explanation")
    ensure(review_decision["rationale_references"], "Review decision lacks rationale references")

    severity = review_decision["decision"]["severity"]
    if severity in HIGH_RISK_LEVELS:
        ensure(reviewer_obligations["required_reviewer_groups"], "High-risk change lacks required reviewers")
        ensure(evidence_obligations["obligations"], "High-risk change lacks evidence obligations")

    ensure(runtime_evaluation["fail_count"] == 0, "Runtime evaluation fixtures are failing")
    ensure(runtime_evaluation["regression_count"] == 0, "Runtime evaluation regressions detected")

    print(
        "DECISION_RUNTIME_OK "
        f"range={canonical_range} severity={severity} "
        f"reviewers={len(reviewer_obligations['required_reviewer_groups'])} "
        f"evidence_obligations={len(evidence_obligations['obligations'])} "
        f"fixture_failures={runtime_evaluation['fail_count']}"
    )


if __name__ == "__main__":
    main()
