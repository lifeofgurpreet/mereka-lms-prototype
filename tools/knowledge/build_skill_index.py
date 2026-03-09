#!/usr/bin/env python3
"""Build the Wave 7 agent skill index."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.build_task_bundle import build_bundle_payload
from tools.knowledge.skill_runtime import load_runtime_inputs


def build_index(repo_root: Path, range_spec: str) -> dict:
    runtime = load_runtime_inputs(repo_root)
    entries = []
    for task_type in runtime["taxonomy"]["task_resolution_order"]:
        task_rule = runtime["taxonomy"]["task_types"][task_type]
        bundle = build_bundle_payload(repo_root, range_spec, task_type)
        entries.append(
            {
                "task_type": task_type,
                "description": task_rule["description"],
                "trigger_roots": task_rule.get("primary_signal_roots", []),
                "trigger_lanes": task_rule.get("primary_signal_lanes", []),
                "trigger_change_classes": task_rule.get("primary_signal_change_classes", []),
                "primary_bundle_json": bundle["bundle_json_path"],
                "primary_bundle_md": bundle["bundle_markdown_path"],
                "primary_commands": bundle["required_commands"],
                "reviewer_policy_sources": [
                    "docs/meta/knowledge/REVIEW_RULES.yaml",
                    "docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml",
                ],
                "evidence_policy_sources": [
                    "docs/meta/knowledge/EVIDENCE_OBLIGATIONS.yaml",
                    "docs/meta/contracts/RELEASE_OBLIGATIONS.yaml",
                ],
                "cross_repo_enabled": task_rule.get("cross_repo_analysis_mandatory", False),
                "escalation_summary": bundle["escalation_conditions"],
            }
        )
    return {
        "generated_by": "tools/knowledge/build_skill_index.py",
        "range": range_spec,
        "task_type_count": len(entries),
        "task_types": entries,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    parser.add_argument("--output", default="generated/knowledge/skill-index.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    payload = build_index(repo_root, args.range_spec)
    rendered = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    output_path = repo_root / args.output
    if args.check:
        if not output_path.exists() or output_path.read_text() != rendered:
            raise SystemExit("SKILL_INDEX_DRIFT")
    else:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(rendered)
    print(f"SKILL_INDEX_OK mode={'check' if args.check else 'write'} task_types={payload['task_type_count']}")


if __name__ == "__main__":
    main()
