#!/usr/bin/env python3
"""Build a docs scorecard artifact from catalog health summary."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--summary-file",
        default="",
        help="Catalog health JSON summary file path",
        required=True,
    )
    parser.add_argument(
        "--out",
        default="docs-scorecard.json",
        help="Output scorecard path",
    )
    parser.add_argument(
        "--min-score",
        type=int,
        default=80,
        help="Minimum passing score (0-100)",
    )
    parser.add_argument(
        "--fail-on-low-score",
        action="store_true",
        help="Exit non-zero if score below threshold",
    )
    return parser.parse_args()


def load_summary(path: str) -> dict:
    with Path(path).open("r", encoding="utf-8") as fp:
        return json.load(fp)


def compute_score(summary: dict) -> int:
    canonical_total = int(summary.get("canonical_total", 0) or 0)
    if canonical_total == 0:
        return 100

    failures = int(summary.get("failures", 0) or 0)
    stale = int(summary.get("canonical_stale", 0) or 0)
    missing_owner = int(summary.get("canonical_missing_owner", 0) or 0)
    missing_verified = int(summary.get("canonical_missing_verified", 0) or 0)
    missing_file = int(summary.get("canonical_missing_file", 0) or 0)
    high_risk = int(summary.get("canonical_high_risk", 0) or 0)

    penalty = (
        failures * 15
        + stale * 8
        + missing_owner * 6
        + missing_verified * 6
        + high_risk * 4
        + missing_file * 25
    )
    score = 100 - penalty
    return max(0, min(100, score))


def main() -> int:
    args = parse_args()
    summary = load_summary(args.summary_file)

    score = compute_score(summary)
    failed = bool(summary.get("failed", False))
    status = "pass" if (not failed and score >= args.min_score) else "warn"
    if args.fail_on_low_score and (failed or score < args.min_score):
        status = "fail"

    scorecard = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "score": score,
        "status": status,
        "threshold": {
            "min_score": args.min_score,
        },
        "catalog_metrics": {
            "catalog_entries": summary.get("all_entries", 0),
            "canonical_entries": summary.get("canonical_total", 0),
            "canonical_stale": summary.get("canonical_stale", 0),
            "canonical_missing_owner": summary.get("canonical_missing_owner", 0),
            "canonical_missing_verified": summary.get("canonical_missing_verified", 0),
            "canonical_missing_file": summary.get("canonical_missing_file", 0),
            "canonical_high_risk": summary.get("canonical_high_risk", 0),
            "failed": summary.get("failed", False),
        },
    }

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(scorecard, indent=2) + "\n", encoding="utf-8")

    print(f"DOCS_SCORECARD status={status} score={score} threshold={args.min_score}")
    if status == "fail":
        print("DOCS_SCORECARD_FAIL: scorecard threshold not met")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
