#!/usr/bin/env python3
"""Verify the Wave 7 task runtime surfaces are current and semantically complete."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.build_skill_index import build_index
from tools.knowledge.build_task_bundle import build_bundle_payload, render_markdown
from tools.knowledge.resolve_task_context import resolve_context
from tools.knowledge.skill_runtime import is_canonical_surface, load_runtime_inputs


def assert_json_matches(path: Path, payload: dict, drift_name: str) -> None:
    rendered = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if not path.exists():
        raise SystemExit(f"MISSING_FILE:{path}")
    if path.read_text() != rendered:
        raise SystemExit(drift_name)


def assert_text_matches(path: Path, rendered: str, drift_name: str) -> None:
    if not path.exists():
        raise SystemExit(f"MISSING_FILE:{path}")
    if path.read_text() != rendered:
        raise SystemExit(drift_name)


def verify(repo_root: Path, range_spec: str) -> dict:
    runtime = load_runtime_inputs(repo_root)
    task_types = runtime["taxonomy"]["task_resolution_order"]
    required_fields = set(runtime["bundle_rules"]["required_bundle_fields"])
    expected_bundle_files = {
        f"{task_type}.json" for task_type in task_types
    } | {
        f"{task_type}.md" for task_type in task_types
    }
    actual_bundle_files = {
        path.name for path in (repo_root / "generated" / "knowledge" / "task-bundles").glob("*")
    }
    if actual_bundle_files != expected_bundle_files:
        raise SystemExit("TASK_BUNDLE_SET_MISMATCH")

    context_payload = resolve_context(repo_root, range_spec)
    assert_json_matches(
        repo_root / "generated" / "knowledge" / "task-context-report.json",
        context_payload,
        "TASK_CONTEXT_REPORT_DRIFT",
    )

    for task_type in task_types:
        bundle = build_bundle_payload(repo_root, range_spec, task_type)
        missing_fields = sorted(required_fields - set(bundle))
        if missing_fields:
            raise SystemExit(f"MISSING_BUNDLE_FIELDS:{task_type}:{','.join(missing_fields)}")
        if not bundle["required_commands"]:
            raise SystemExit(f"EMPTY_COMMAND_SET:{task_type}")
        if runtime["taxonomy"]["task_types"][task_type]["risk"] == "high":
            if not bundle["required_reviewers"]:
                raise SystemExit(f"HIGH_RISK_REVIEWERS_MISSING:{task_type}")
            if not bundle["required_evidence"]:
                raise SystemExit(f"HIGH_RISK_EVIDENCE_MISSING:{task_type}")
        if runtime["taxonomy"]["task_types"][task_type].get("cross_repo_analysis_mandatory"):
            required_sources = {
                "generated/contracts/cross-repo-manifest.json",
                "generated/contracts/deployment-impact-report.json",
                "generated/contracts/release-obligations.md",
            }
            if not required_sources.issubset(set(bundle["source_runtime_artifacts"])):
                raise SystemExit(f"CROSS_REPO_SOURCE_MISSING:{task_type}")

        for section_name in [
            "related_contracts",
            "related_specs",
            "related_runbooks",
            "related_generated_surfaces",
            "affected_truth_surfaces",
        ]:
            for path in bundle[section_name]:
                if not is_canonical_surface(repo_root, path):
                    raise SystemExit(f"NON_CANONICAL_PATH:{task_type}:{path}")

        for item in bundle["read_first"]:
            if not is_canonical_surface(repo_root, item["path"]):
                raise SystemExit(f"NON_CANONICAL_READ_FIRST:{task_type}:{item['path']}")

        assert_json_matches(repo_root / bundle["bundle_json_path"], bundle, f"TASK_BUNDLE_JSON_DRIFT:{task_type}")
        assert_text_matches(repo_root / bundle["bundle_markdown_path"], render_markdown(bundle), f"TASK_BUNDLE_MD_DRIFT:{task_type}")

    index = build_index(repo_root, range_spec)
    assert_json_matches(repo_root / "generated" / "knowledge" / "skill-index.json", index, "SKILL_INDEX_DRIFT")
    bundle_types = {task_type for task_type in task_types}
    index_types = {entry["task_type"] for entry in index["task_types"]}
    if bundle_types != index_types:
        raise SystemExit("SKILL_INDEX_TASK_SET_MISMATCH")

    return {
        "task_types": len(task_types),
        "high_risk_task_types": sum(1 for task_type in task_types if runtime["taxonomy"]["task_types"][task_type]["risk"] == "high"),
        "primary_task_type": context_payload["primary_task_type"],
        "confidence": context_payload["confidence"],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    summary = verify(repo_root, args.range_spec)
    print(
        "TASK_RUNTIME_OK "
        f"task_types={summary['task_types']} "
        f"high_risk_task_types={summary['high_risk_task_types']} "
        f"primary_task_type={summary['primary_task_type']} "
        f"confidence={summary['confidence']}"
    )


if __name__ == "__main__":
    main()
