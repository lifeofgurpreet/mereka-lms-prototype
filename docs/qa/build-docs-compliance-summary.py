#!/usr/bin/env python3
"""Build a consolidated docs compliance summary from existing docs QA artifacts."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--foundation-summary", required=False, default="", help="docs-foundation-summary.json")
    p.add_argument("--cmdref-baseline-summary", required=False, default="", help="docs-cmdref-baseline-summary.json")
    p.add_argument("--catalog-summary", required=True, help="docs-catalog-health-summary.json")
    p.add_argument("--cmdref-summary", required=True, help="docs-command-refs-summary.json")
    p.add_argument("--scorecard", required=False, default="", help="docs-scorecard.json")
    p.add_argument("--comparison", required=False, default="", help="docs-scorecard-comparison.json")
    p.add_argument("--scorecard-recency-summary", required=False, default="", help="docs-scorecard-recency-summary.json")
    p.add_argument(
        "--scorecard-consistency-summary",
        required=False,
        default="",
        help="docs-scorecard-consistency-summary.json",
    )
    p.add_argument(
        "--scorecard-head-freshness-summary",
        required=False,
        default="",
        help="docs-scorecard-head-freshness-summary.json",
    )
    p.add_argument(
        "--scorecard-timestamp-summary",
        required=False,
        default="",
        help="docs-scorecard-timestamp-summary.json",
    )
    p.add_argument(
        "--scorecard-delta-summary",
        required=False,
        default="",
        help="docs-scorecard-delta-summary.json",
    )
    p.add_argument(
        "--scorecard-drift-summary",
        required=False,
        default="",
        help="docs-scorecard-drift-summary.json",
    )
    p.add_argument(
        "--link-integrity-summary",
        required=False,
        default="",
        help="docs-link-integrity-summary.json",
    )
    p.add_argument("--out", required=False, default="docs-compliance-summary.json", help="output path")
    return p.parse_args()


def _safe_load(path: str, default):
    if not path:
        return default
    p = Path(path)
    if not p.exists():
        return default
    with p.open("r", encoding="utf-8") as fp:
        return json.load(fp)


def _status_from_catalog(summary: dict) -> str:
    if not summary:
        return "unknown"
    if summary.get("failed"):
        return "fail"
    return "pass"


def _status_from_cmdref(summary: dict) -> str:
    if not summary:
        return "unknown"
    return str(summary.get("status", "unknown")).lower()


def _status_from_comparison(summary: dict) -> str:
    if not summary:
        return "unknown"
    return str(summary.get("status", "unknown")).lower()


def _status_from_scorecard(summary: dict) -> str:
    if not summary:
        return "unknown"
    return str(summary.get("status", "unknown")).lower()


def _normalized_status(value: str) -> str:
    value = value.lower()
    if value in {"pass", "warn", "fail", "unknown"}:
        return value
    return "unknown"


def main() -> int:
    args = parse_args()

    foundation = _safe_load(args.foundation_summary, {})
    cmdref_baseline = _safe_load(args.cmdref_baseline_summary, {})
    catalog = _safe_load(args.catalog_summary, {})
    cmdref = _safe_load(args.cmdref_summary, {})
    scorecard = _safe_load(args.scorecard, {})
    comparison = _safe_load(args.comparison, {})
    scorecard_recency = _safe_load(args.scorecard_recency_summary, {})
    scorecard_consistency = _safe_load(args.scorecard_consistency_summary, {})
    scorecard_head_freshness = _safe_load(args.scorecard_head_freshness_summary, {})
    scorecard_timestamp = _safe_load(args.scorecard_timestamp_summary, {})
    scorecard_delta = _safe_load(args.scorecard_delta_summary, {})
    scorecard_drift = _safe_load(args.scorecard_drift_summary, {})
    link_integrity = _safe_load(args.link_integrity_summary, {})

    foundation_status = _normalized_status(_status_from_scorecard(foundation))
    foundation_policy_status = _normalized_status(str(foundation.get("policy_status", "unknown")))
    foundation_repo_status = _normalized_status(str(foundation.get("repo_structure_status", "unknown")))
    foundation_policy_content_source_status = _normalized_status(str(foundation.get("policy_content_status", "unknown")))
    foundation_policy_content_errors = foundation.get("policy_content_errors", [])
    foundation_policy_content_status = foundation_policy_content_source_status
    if foundation_policy_content_errors and foundation_policy_content_status == "pass":
        foundation_policy_content_status = "fail"
    policy_content_consistent = foundation_policy_content_status == foundation_policy_content_source_status
    cmdref_baseline_status = _normalized_status(_status_from_scorecard(cmdref_baseline))
    catalog_status = _status_from_catalog(catalog)
    cmdref_status = _normalized_status(_status_from_cmdref(cmdref))
    scorecard_status = _normalized_status(_status_from_scorecard(scorecard))
    comparison_status = _normalized_status(_status_from_comparison(comparison))
    recency_status = _normalized_status(_status_from_scorecard(scorecard_recency))
    consistency_status = _normalized_status(_status_from_scorecard(scorecard_consistency))
    head_freshness_status = _normalized_status(_status_from_scorecard(scorecard_head_freshness))
    timestamp_status = _normalized_status(_status_from_scorecard(scorecard_timestamp))
    delta_status = _normalized_status(_status_from_scorecard(scorecard_delta))
    drift_status = _normalized_status(_status_from_scorecard(scorecard_drift))
    link_integrity_status = _normalized_status(_status_from_scorecard(link_integrity))
    catalog_status = _normalized_status(catalog_status)

    statuses = {
        "catalog_health": catalog_status,
        "foundation_gates": foundation_status,
        "foundation_policy": foundation_policy_status,
        "foundation_repo_structure": foundation_repo_status,
        "foundation_policy_content": foundation_policy_content_status,
        "foundation_policy_content_consistency": "pass" if policy_content_consistent else "fail",
        "command_reference_baseline": cmdref_baseline_status,
        "link_integrity": link_integrity_status,
        "command_references": cmdref_status,
        "docs_scorecard": scorecard_status,
        "scorecard_trend": comparison_status,
        "scorecard_recency": recency_status,
        "scorecard_consistency": consistency_status,
        "scorecard_head_freshness": head_freshness_status,
        "scorecard_timestamp_format": timestamp_status,
        "scorecard_delta_artifact": delta_status,
        "scorecard_generation_drift": drift_status,
    }

    terminal_status = "pass"
    if "fail" in statuses.values():
        terminal_status = "fail"
    elif "unknown" in statuses.values() or "warn" in statuses.values():
        terminal_status = "warn"

    payload = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "overall_status": terminal_status,
        "statuses": statuses,
        "catalog_health": {
            "status": catalog_status,
            "canonical_total": catalog.get("canonical_total", 0),
            "canonical_stale": catalog.get("canonical_stale", 0),
            "canonical_missing_owner": catalog.get("canonical_missing_owner", 0),
            "canonical_missing_verified": catalog.get("canonical_missing_verified", 0),
            "canonical_missing_file": catalog.get("canonical_missing_file", 0),
            "canonical_high_risk": catalog.get("canonical_high_risk", 0),
            "failed": catalog.get("failed", False),
        },
        "foundation_gates": {
            "status": foundation_status,
            "policy_status": foundation_policy_status,
            "repo_structure_status": foundation_repo_status,
            "policy_range": foundation.get("policy_range", ""),
            "policy_root_allowlist_violations": foundation.get("policy_root_allowlist_violations", 0),
            "policy_changed_markdown_files": foundation.get("policy_changed_markdown_files", 0),
            "policy_content_status": foundation_policy_content_status,
            "policy_content_consistent": policy_content_consistent,
            "policy_content_errors": foundation_policy_content_errors,
        },
        "command_reference_baseline": {
            "status": cmdref_baseline_status,
            "baseline_file": cmdref_baseline.get("baseline_file", ""),
            "entries": cmdref_baseline.get("entries", 0),
            "duplicates": cmdref_baseline.get("duplicates", []),
            "missing": cmdref_baseline.get("missing", []),
            "invalid_non_markdown": cmdref_baseline.get("invalid_non_markdown", []),
        },
        "command_refs": {
            "status": cmdref_status,
            "files_checked": cmdref.get("files_checked", 0),
            "baseline_enabled": cmdref.get("baseline_enabled", False),
            "baseline_entries": cmdref.get("baseline_entries", 0),
            "total_candidates": cmdref.get("total_candidates", 0),
            "missing_references": cmdref.get("missing_references", 0),
            "missing": cmdref.get("missing", []),
        },
        "link_integrity": {
            "status": link_integrity_status,
            "files_checked": link_integrity.get("files_checked", 0),
            "broken_links": link_integrity.get("broken_links", 0),
            "broken": link_integrity.get("broken", []),
        },
        "docs_scorecard": {
            "status": scorecard_status,
            "score": scorecard.get("score", 0),
            "threshold": scorecard.get("threshold", {}).get("min_score", 0),
            "catalog_metrics": scorecard.get("catalog_metrics", {}),
        },
        "docs_scorecard_trend": {
            "status": comparison_status,
            "base_ref": comparison.get("base_ref", ""),
            "base_score": comparison.get("base_score", 0),
            "current_score": comparison.get("current_score", 0),
            "score_drop": comparison.get("score_drop", 0),
            "max_allowed_drop": comparison.get("max_allowed_drop", 0),
        },
        "docs_scorecard_recency": {
            "status": recency_status,
            "latest_report": scorecard_recency.get("latest_report", ""),
            "latest_date": scorecard_recency.get("latest_date", ""),
            "age_days": scorecard_recency.get("age_days", 0),
            "max_age_days": scorecard_recency.get("max_age_days", 0),
        },
        "docs_scorecard_consistency": {
            "status": consistency_status,
            "reports_checked": scorecard_consistency.get("reports_checked", 0),
            "invalid_reports": scorecard_consistency.get("invalid_reports", 0),
            "mismatches": scorecard_consistency.get("mismatches", []),
        },
        "docs_scorecard_head_freshness": {
            "status": head_freshness_status,
            "latest_report": scorecard_head_freshness.get("latest_report", ""),
            "latest_date": scorecard_head_freshness.get("latest_date", ""),
            "reference_date": scorecard_head_freshness.get("reference_date", ""),
        },
        "docs_scorecard_timestamp_format": {
            "status": timestamp_status,
            "reports_checked": scorecard_timestamp.get("reports_checked", 0),
            "invalid_reports": scorecard_timestamp.get("invalid_reports", 0),
            "mismatches": scorecard_timestamp.get("mismatches", []),
        },
        "docs_scorecard_delta_artifact": {
            "status": delta_status,
            "latest_program_report": scorecard_delta.get("latest_program_report", ""),
            "latest_program_date": scorecard_delta.get("latest_program_date", ""),
            "latest_delta_report": scorecard_delta.get("latest_delta_report", ""),
            "latest_delta_date": scorecard_delta.get("latest_delta_date", ""),
            "date_match": scorecard_delta.get("date_match", False),
            "has_delta_section": scorecard_delta.get("has_delta_section", False),
        },
        "docs_scorecard_generation_drift": {
            "status": drift_status,
            "latest_date": scorecard_drift.get("latest_date", ""),
            "program_report": scorecard_drift.get("program_report", ""),
            "quality_report": scorecard_drift.get("quality_report", ""),
            "program_match": scorecard_drift.get("program_match", False),
            "quality_match": scorecard_drift.get("quality_match", False),
        },
    }

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    print(
        "DOCS_COMPLIANCE_SUMMARY "
        f"overall_status={terminal_status} "
        f"foundation={foundation_status} policy={foundation_policy_status} repo_structure={foundation_repo_status} "
        f"policy_content={foundation_policy_content_status} "
        f"policy_content_consistency_status={statuses['foundation_policy_content_consistency']} "
        f"policy_content_consistent={str(policy_content_consistent).lower()} "
        f"cmdref_baseline={cmdref_baseline_status} "
        f"catalog={catalog_status} link_integrity={link_integrity_status} cmdref={cmdref_status} "
        f"scorecard={scorecard_status} trend={comparison_status} "
        f"recency={recency_status} consistency={consistency_status} "
        f"head_freshness={head_freshness_status} timestamp={timestamp_status} "
        f"delta={delta_status} drift={drift_status}"
    )

    if terminal_status == "fail":
        print("DOCS_COMPLIANCE_SUMMARY_FAIL: one or more required checks failed")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
