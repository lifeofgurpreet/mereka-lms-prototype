#!/usr/bin/env python3
"""Verify the Wave 5 change-intelligence runtime surfaces are current and coherent."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.build_change_manifest import build_manifest
from tools.knowledge.build_review_bundle import build_bundle
from tools.knowledge.build_truth_impact_report import build_report as build_truth_impact_report
from tools.knowledge.build_wrapper_retirement_report import build_report as build_wrapper_report

REQUIRED_EVIDENCE_KEYS = {
    "require_status_update",
    "require_evidence_pack",
    "require_runbook_update",
    "require_adr_update",
    "require_plan_refresh",
    "require_testplan_refresh",
}


def assert_json_matches(path: Path, payload: dict, drift_name: str) -> None:
    rendered = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if not path.exists():
        raise SystemExit(f"Missing generated file: {path}")
    if path.read_text() != rendered:
        raise SystemExit(drift_name)


def assert_text_matches(path: Path, rendered: str, drift_name: str) -> None:
    if not path.exists():
        raise SystemExit(f"Missing generated file: {path}")
    if path.read_text() != rendered:
        raise SystemExit(drift_name)


def assert_runtime_policy(manifest: dict) -> None:
    for entry in manifest.get("entries", []):
        if entry.get("root") not in {"docs", "specs"}:
            continue
        if entry.get("change_risk") not in {"high", "medium"}:
            continue

        required_reviewers = entry.get("review", {}).get("required_reviewers", [])
        if not required_reviewers:
            raise SystemExit(f"MISSING_REQUIRED_REVIEWERS:{entry['path']}")

        evidence = entry.get("evidence", {})
        if not REQUIRED_EVIDENCE_KEYS.issubset(set(evidence.keys())):
            raise SystemExit(f"INCOMPLETE_EVIDENCE_CLASSIFICATION:{entry['path']}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    manifest = build_manifest(repo_root, args.range_spec)
    review_bundle = build_bundle(repo_root, args.range_spec)
    truth_impact = build_truth_impact_report(repo_root, args.range_spec)
    wrapper_report = build_wrapper_report(repo_root)

    assert_json_matches(
        repo_root / "generated" / "knowledge" / "change-manifest.json",
        manifest,
        "CHANGE_MANIFEST_DRIFT",
    )
    assert_text_matches(
        repo_root / "generated" / "knowledge" / "review-bundle.md",
        review_bundle,
        "REVIEW_BUNDLE_DRIFT",
    )
    assert_json_matches(
        repo_root / "generated" / "knowledge" / "truth-impact-report.json",
        truth_impact,
        "TRUTH_IMPACT_REPORT_DRIFT",
    )
    assert_json_matches(
        repo_root / "generated" / "knowledge" / "wrapper-retirement-report.json",
        wrapper_report,
        "WRAPPER_RETIREMENT_REPORT_DRIFT",
    )
    assert_runtime_policy(manifest)

    required_reviewers = manifest.get("required_reviewers", [])
    wrapper_status_counts = wrapper_report.get("status_counts", {})
    print(
        "KNOWLEDGE_RUNTIME_OK "
        f"changes={manifest['change_count']} "
        f"reviewers={','.join(required_reviewers) or 'none'} "
        f"safe_to_retire={wrapper_status_counts.get('safe_to_retire', 0)} "
        f"suspicious_wrappers="
        f"{wrapper_status_counts.get('suspicious', 0) + wrapper_status_counts.get('active_but_suspicious', 0)}"
    )


if __name__ == "__main__":
    main()
