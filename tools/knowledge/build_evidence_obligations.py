#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import jsonschema


DEFAULT_OUTPUT = Path("generated/knowledge/evidence-obligations.json")
SCHEMA_PATH = Path("docs/meta/knowledge/schemas/evidence-obligations.schema.json")

OBLIGATION_TYPE_MAP = {
    "catalog_governance": "required_status_update",
    "docs_policy": "required_status_update",
    "source_of_truth_map": "required_evidence_pack",
    "validation_run": "required_evidence_pack",
    "release_contract": "required_adr_update",
    "workflow_dispatch": "required_plan_testplan_refresh",
    "release_notes_diff": "required_status_update",
    "release_obligations": "required_evidence_pack",
    "rollback_target_reference": "required_runbook_update",
    "runbook_reference": "required_runbook_update",
    "service_identity": "required_evidence_pack",
    "smoke_test_result": "required_evidence_pack",
    "topology_contract": "required_evidence_pack",
    "transitional_residue": "required_status_update",
    "cross_repo_alignment": "required_evidence_pack",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 12 evidence obligations.")
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
            raise SystemExit(f"Evidence obligations drift detected: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def build_payload(
    review_decision: dict[str, Any],
    skill_registry: dict[str, Any],
    evidence_map: dict[str, Any],
) -> dict[str, Any]:
    selected = set(review_decision["decision"]["selected_skills"])
    skill_index = {skill["skill_id"]: skill for skill in skill_registry["skills"]}
    evidence_index = {item["evidence_class"]: item for item in evidence_map["evidence_classes"]}

    obligations = []
    status_updates: set[str] = set()
    evidence_packs: set[str] = set()
    runbook_updates: set[str] = set()
    adr_updates: set[str] = set()
    plan_refreshes: set[str] = set()

    for skill_id in sorted(selected):
        for evidence_class in skill_index[skill_id]["required_evidence_classes"]:
            obligation_type = OBLIGATION_TYPE_MAP.get(evidence_class, "required_evidence_pack")
            blocking = review_decision["decision"]["severity"] in {"high", "release-critical"}
            source_rule = evidence_index[evidence_class]["sufficiency_policy"]
            obligations.append(
                {
                    "obligation_type": obligation_type,
                    "evidence_class": evidence_class,
                    "blocking": blocking,
                    "source_rule": source_rule,
                    "triggered_by_skills": [skill_id],
                    "advisory_note": (
                        "live approval state is unresolved input"
                        if evidence_class in {"release_contract", "release_obligations", "smoke_test_result"}
                        else ""
                    ),
                }
            )
            if obligation_type == "required_status_update":
                status_updates.add(evidence_class)
            elif obligation_type == "required_evidence_pack":
                evidence_packs.add(evidence_class)
            elif obligation_type == "required_runbook_update":
                runbook_updates.add(evidence_class)
            elif obligation_type == "required_adr_update":
                adr_updates.add(evidence_class)
            elif obligation_type == "required_plan_testplan_refresh":
                plan_refreshes.add(evidence_class)

    return {
        "pack_id": "evidence-obligations",
        "generated_by": "tools/knowledge/build_evidence_obligations.py",
        "source_range": review_decision["source_range"],
        "canonical_inputs": sorted(
            {
                "generated/knowledge/review-decision.json",
                "generated/skills/skill-registry.json",
                "generated/skills/evidence-sufficiency-map.json",
                "docs/meta/knowledge/DECISION_RUNTIME_MODEL.md",
            }
        ),
        "schema_version": 1,
        "diff_range": review_decision["diff_range"],
        "required_status_updates": sorted(status_updates),
        "required_evidence_packs": sorted(evidence_packs),
        "required_runbook_updates": sorted(runbook_updates),
        "required_adr_updates": sorted(adr_updates),
        "required_plan_testplan_refreshes": sorted(plan_refreshes),
        "obligations": obligations,
    }


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    schema = load_json(repo_root / SCHEMA_PATH)
    review_decision = load_json(repo_root / "generated/knowledge/review-decision.json")
    skill_registry = load_json(repo_root / "generated/skills/skill-registry.json")
    evidence_map = load_json(repo_root / "generated/skills/evidence-sufficiency-map.json")
    payload = build_payload(review_decision, skill_registry, evidence_map)
    jsonschema.validate(instance=payload, schema=schema)
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    write_or_check(output_path, serialized, args.check)
    mode = "check" if args.check else "write"
    print(
        "EVIDENCE_OBLIGATIONS_OK "
        f"mode={mode} evidence_packs={len(payload['required_evidence_packs'])} "
        f"blocking={sum(1 for item in payload['obligations'] if item['blocking'])}"
    )


if __name__ == "__main__":
    main()
