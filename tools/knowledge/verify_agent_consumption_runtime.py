#!/usr/bin/env python3
"""Verify Wave 8 agent-consumption artifacts are current and semantically complete."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.build_agent_entrypoints import build_entrypoints
from tools.knowledge.build_agent_readiness_report import build_report
from tools.knowledge.build_agent_task_bundles import FILE_NAME_MAP, build_bundle, expected_bundle_files, render_bundle_markdown


def assert_text_matches(path: Path, rendered: str, drift_name: str) -> None:
    if not path.exists():
        raise SystemExit(f"MISSING_FILE:{path}")
    if path.read_text() != rendered:
        raise SystemExit(drift_name)


def assert_json_matches(path: Path, payload: dict, drift_name: str) -> None:
    rendered = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if not path.exists():
        raise SystemExit(f"MISSING_FILE:{path}")
    if path.read_text() != rendered:
        raise SystemExit(drift_name)


def verify(repo_root: Path, range_spec: str) -> dict[str, int]:
    entrypoints_payload = build_entrypoints(repo_root)
    assert_json_matches(
        repo_root / "generated" / "knowledge" / "agent-entrypoints.json",
        entrypoints_payload,
        "AGENT_ENTRYPOINTS_DRIFT",
    )
    if entrypoints_payload["unresolved_domains"]:
        raise SystemExit("UNRESOLVED_DOMAINS_PRESENT")

    bundle_dir = repo_root / "generated" / "knowledge" / "agent-task-bundles"
    actual_files = {path.name for path in bundle_dir.glob("*.md")}
    if actual_files != expected_bundle_files():
        raise SystemExit("AGENT_TASK_BUNDLE_SET_MISMATCH")

    for task_type, file_name in FILE_NAME_MAP.items():
        bundle = build_bundle(repo_root, task_type)
        assert_text_matches(bundle_dir / file_name, render_bundle_markdown(bundle), f"AGENT_TASK_BUNDLE_DRIFT:{task_type}")
        if not bundle["read_first"]:
            raise SystemExit(f"MISSING_READ_FIRST:{task_type}")
        if not bundle["required_validation_commands"]:
            raise SystemExit(f"MISSING_VALIDATION_COMMANDS:{task_type}")
        if not bundle["required_reviewers"]:
            raise SystemExit(f"MISSING_REVIEWERS:{task_type}")
        if not bundle["required_evidence"]:
            raise SystemExit(f"MISSING_EVIDENCE:{task_type}")
        for item in bundle["read_first"]:
            if item["lane"] == "archive":
                raise SystemExit(f"ARCHIVE_READ_FIRST_LEAK:{task_type}:{item['path']}")

    readiness_payload = build_report(repo_root, range_spec)
    assert_json_matches(
        repo_root / "generated" / "knowledge" / "agent-readiness-report.json",
        readiness_payload,
        "AGENT_READINESS_REPORT_DRIFT",
    )
    if readiness_payload["forbidden_surface_leaks"]:
        raise SystemExit("FORBIDDEN_SURFACE_LEAKS_PRESENT")
    if readiness_payload["unresolved_tasks"]:
        raise SystemExit("UNRESOLVED_TASKS_PRESENT")

    return {
        "domains": entrypoints_payload["domain_count"],
        "bundles": readiness_payload["task_bundle_count"],
        "forbidden_surface_leaks": len(readiness_payload["forbidden_surface_leaks"]),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", default="origin/main...HEAD")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    summary = verify(repo_root, args.range)
    print(
        f"AGENT_CONSUMPTION_RUNTIME_OK domains={summary['domains']} "
        f"bundles={summary['bundles']} forbidden_surface_leaks={summary['forbidden_surface_leaks']}"
    )


if __name__ == "__main__":
    main()
