#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import jsonschema


DEFAULT_OUTPUT = Path("generated/knowledge/runtime-evaluation.json")
SCHEMA_PATH = Path("docs/meta/knowledge/schemas/runtime-evaluation.schema.json")
FIXTURE_PATH = Path("fixtures/decision-runtime/scenarios.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 12 runtime evaluation from deterministic fixtures.")
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
            raise SystemExit(f"Runtime evaluation drift detected: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def compute_reviewers(skill_index: dict[str, Any], selected_skills: list[str]) -> list[str]:
    reviewers = sorted({reviewer for skill_id in selected_skills for reviewer in skill_index[skill_id]["required_reviewers"]})
    return reviewers


def compute_evidence_classes(skill_index: dict[str, Any], selected_skills: list[str]) -> list[str]:
    return sorted({e for skill_id in selected_skills for e in skill_index[skill_id]["required_evidence_classes"]})


def compute_read_first(skill_index: dict[str, Any], selected_skills: list[str], severity: str) -> list[str]:
    pack_ids = set()
    for skill_id in selected_skills:
        pack_ids.update(skill_index[skill_id]["pack_dependencies"])
    high = {"pack-registry", "runtime-convergence-report", "mixed-diff-arbitration", "evidence-sufficiency-map"}
    medium = {"read-first"}
    pack_order = [
        "pack-registry",
        "skill-registry",
        "runtime-convergence-report",
        "evidence-sufficiency-map",
        "mixed-diff-arbitration",
        "read-first",
    ]
    return sorted(
        pack_ids,
        key=lambda pack_id: (
            0 if pack_id in high and severity in {"high", "release-critical"} else 1 if pack_id in medium or pack_id in high else 2,
            pack_order.index(pack_id) if pack_id in pack_order else len(pack_order),
            pack_id,
        ),
    )


def compute_release_status(severity: str, runtime_state: str) -> str:
    if runtime_state == "fail":
        return "blocked"
    if severity == "release-critical" and runtime_state == "warning":
        return "break-glass-only"
    if severity in {"high", "release-critical"}:
        return "advisory"
    return "ready"


def evaluate_fixture(scenario: dict[str, Any], skill_index: dict[str, Any]) -> dict[str, Any]:
    actual_reviewers = compute_reviewers(skill_index, scenario["selected_skills"])
    actual_evidence = compute_evidence_classes(skill_index, scenario["selected_skills"])
    actual_release = compute_release_status(scenario["severity"], scenario["runtime_convergence_state"])
    actual_read_first = compute_read_first(skill_index, scenario["selected_skills"], scenario["severity"])

    mismatches = []
    if actual_reviewers != scenario["expected_reviewers"]:
        mismatches.append("reviewer set mismatch")
    if actual_evidence != scenario["expected_evidence_classes"]:
        mismatches.append("evidence classes mismatch")
    if actual_release != scenario["expected_release_status"]:
        mismatches.append("release readiness mismatch")
    if actual_read_first != scenario["expected_read_first_order"]:
        mismatches.append("read-first order mismatch")

    return {
        "scenario_id": scenario["scenario_id"],
        "pass": not mismatches,
        "expected_reviewers": scenario["expected_reviewers"],
        "actual_reviewers": actual_reviewers,
        "expected_evidence_classes": scenario["expected_evidence_classes"],
        "actual_evidence_classes": actual_evidence,
        "expected_release_status": scenario["expected_release_status"],
        "actual_release_status": actual_release,
        "expected_read_first_order": scenario["expected_read_first_order"],
        "actual_read_first_order": actual_read_first,
        "mismatches": mismatches,
    }


def build_payload(skill_registry: dict[str, Any], fixtures: dict[str, Any]) -> dict[str, Any]:
    skill_index = {skill["skill_id"]: skill for skill in skill_registry["skills"]}
    results = [evaluate_fixture(scenario, skill_index) for scenario in fixtures["scenarios"]]
    pass_count = sum(1 for item in results if item["pass"])
    fail_count = len(results) - pass_count

    return {
        "pack_id": "runtime-evaluation",
        "generated_by": "tools/knowledge/build_runtime_evaluation.py",
        "source_range": None,
        "canonical_inputs": sorted(
            {
                "fixtures/decision-runtime/scenarios.json",
                "generated/skills/skill-registry.json",
                "generated/skills/pack-registry.json",
                "generated/skills/evidence-sufficiency-map.json",
                "generated/skills/mixed-diff-arbitration.json",
                "docs/meta/knowledge/DECISION_RUNTIME_MODEL.md",
            }
        ),
        "schema_version": 1,
        "scenarios_run": len(results),
        "pass_count": pass_count,
        "fail_count": fail_count,
        "regression_count": fail_count,
        "false_positive_notes": [],
        "unresolved_ambiguities": [
            "release readiness does not model live approval state",
            "runtime convergence warnings still require manual follow-up",
        ],
        "scenario_results": results,
    }


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    schema = load_json(repo_root / SCHEMA_PATH)
    skill_registry = load_json(repo_root / "generated/skills/skill-registry.json")
    fixtures = load_json(repo_root / FIXTURE_PATH)
    payload = build_payload(skill_registry, fixtures)
    jsonschema.validate(instance=payload, schema=schema)
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    write_or_check(output_path, serialized, args.check)
    mode = "check" if args.check else "write"
    print(
        "RUNTIME_EVALUATION_OK "
        f"mode={mode} scenarios={payload['scenarios_run']} "
        f"pass={payload['pass_count']} fail={payload['fail_count']}"
    )


if __name__ == "__main__":
    main()
