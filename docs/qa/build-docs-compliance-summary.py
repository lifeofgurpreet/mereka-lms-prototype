#!/usr/bin/env python3
"""Build a consolidated docs compliance summary from existing docs QA artifacts."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--catalog-summary", required=True, help="docs-catalog-health-summary.json")
    p.add_argument("--cmdref-summary", required=True, help="docs-command-refs-summary.json")
    p.add_argument("--scorecard", required=False, default="", help="docs-scorecard.json")
    p.add_argument("--comparison", required=False, default="", help="docs-scorecard-comparison.json")
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

    catalog = _safe_load(args.catalog_summary, {})
    cmdref = _safe_load(args.cmdref_summary, {})
    scorecard = _safe_load(args.scorecard, {})
    comparison = _safe_load(args.comparison, {})

    catalog_status = _status_from_catalog(catalog)
    cmdref_status = _normalized_status(_status_from_cmdref(cmdref))
    scorecard_status = _normalized_status(_status_from_scorecard(scorecard))
    comparison_status = _normalized_status(_status_from_comparison(comparison))
    catalog_status = _normalized_status(catalog_status)

    statuses = {
        "catalog_health": catalog_status,
        "command_references": cmdref_status,
        "docs_scorecard": scorecard_status,
        "scorecard_trend": comparison_status,
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
        "command_refs": {
            "status": cmdref_status,
            "files_checked": cmdref.get("files_checked", 0),
            "total_candidates": cmdref.get("total_candidates", 0),
            "missing_references": cmdref.get("missing_references", 0),
            "missing": cmdref.get("missing", []),
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
    }

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    print(
        "DOCS_COMPLIANCE_SUMMARY "
        f"overall_status={terminal_status} "
        f"catalog={catalog_status} cmdref={cmdref_status} "
        f"scorecard={scorecard_status} trend={comparison_status}"
    )

    if terminal_status == "fail":
        print("DOCS_COMPLIANCE_SUMMARY_FAIL: one or more required checks failed")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
