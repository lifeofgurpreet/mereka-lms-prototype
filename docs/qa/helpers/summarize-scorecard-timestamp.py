#!/usr/bin/env python3
"""Append docs scorecard timestamp format summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Docs Scorecard Timestamp Format\n")
    fp.write(f"- status={payload.get('status', 'unknown')}\n")
    fp.write(f"- reports_checked={payload.get('reports_checked', 'n/a')}\n")
    fp.write(f"- invalid_reports={payload.get('invalid_reports', 'n/a')}\n")
