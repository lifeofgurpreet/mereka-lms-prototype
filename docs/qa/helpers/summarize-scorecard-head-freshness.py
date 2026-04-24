#!/usr/bin/env python3
"""Append docs scorecard head freshness summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Docs Scorecard Head Freshness\n")
    fp.write(f"- status={payload.get('status', 'unknown')}\n")
    fp.write(f"- latest_report={payload.get('latest_report', 'n/a')}\n")
    fp.write(f"- latest_date={payload.get('latest_date', 'n/a')}\n")
    fp.write(f"- reference_date={payload.get('reference_date', 'n/a')}\n")
