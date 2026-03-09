#!/usr/bin/env python3
"""Verify the Wave 7 task runtime surfaces are current and coherent."""

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
from tools.knowledge.task_runtime import load_task_runtime_inputs


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


def assert_path_is_canonical(rel_path: str) -> None:
    if rel_path.startswith("docs/archive/") or rel_path.startswith("specs/archive/"):
        raise SystemExit(f"NON_CANONICAL_PATH:{rel_path}")
    if rel_path.startswith("specs/") and rel_path.endswith("_spec.md"):
        forbidden = {
            "specs/external-registration-hubspot_spec.md",
            "specs/mobile-apps-enterprise_spec.md",
            "specs/proctoring-integration_spec.md",
        }
        if rel_path in forbidden:
            raise SystemExit(f"NON_CANONICAL_WRAPPER:{rel_path}")


def verify(repo_root: Path, range_spec: str) -> dict:
    runtime = load_task_runtime_inputs(repo_root)
    required_fields = set(runtime["bundle_rules"]["required_bundle_fields"])
    task_types = runtime["taxonomy"]["task_resolution_order"]

    for task_type in task_types:
        bundle = build_bundle_payload(repo_root, range_spec, task_type)
        bundle_json_path = repo_root / bundle["bundle_json_path"]
        bundle_md_path = repo_root / bundle["bundle_markdown_path"]

        missing = sorted(required_fields - set(bundle))
        if missing:
            raise SystemExit(f"MISSING_BUNDLE_FIELDS:{task_type}:{','.join(missing)}")

        assert_json_matches(bundle_json_path, bundle, f"TASK_BUNDLE_JSON_DRIFT:{task_type}")
        assert_text_matches(bundle_md_path, render_markdown(bundle), f"TASK_BUNDLE_MD_DRIFT:{task_type}")

        if bundle["authority_order"] != runtime["bundle_rules"]["authority_order"]:
            raise SystemExit(f"AUTHORITY_ORDER_MISMATCH:{task_type}")

        for surface in (
            bundle["read_first"]
            + bundle["generated_surfaces_to_refresh"]
            + bundle["affected_truth_surfaces"]
        ):
            assert_path_is_canonical(surface)
            if not (repo_root / surface).exists():
                raise SystemExit(f"MISSING_REFERENCED_SURFACE:{task_type}:{surface}")

        risk = runtime["taxonomy"]["task_types"][task_type]["risk"]
        if risk == "high":
            if not bundle["required_reviewers"]:
                raise SystemExit(f"HIGH_RISK_REVIEWERS_MISSING:{task_type}")
            if not bundle["required_evidence"]:
                raise SystemExit(f"HIGH_RISK_EVIDENCE_MISSING:{task_type}")
            if not bundle["required_commands"]:
                raise SystemExit(f"HIGH_RISK_COMMANDS_MISSING:{task_type}")

    skill_index = build_index(repo_root, range_spec)
    assert_json_matches(
        repo_root / "generated" / "knowledge" / "skill-index.json",
        skill_index,
        "SKILL_INDEX_DRIFT",
    )
    skill_index_types = {item["task_type"] for item in skill_index["task_types"]}
    if set(task_types) != skill_index_types:
        raise SystemExit("SKILL_INDEX_TASK_SET_MISMATCH")

    return {
        "task_types": len(task_types),
        "high_risk_task_types": sum(
            1 for task in task_types if runtime["taxonomy"]["task_types"][task]["risk"] == "high"
        ),
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
        f"high_risk_task_types={summary['high_risk_task_types']}"
    )


if __name__ == "__main__":
    main()
