#!/usr/bin/env python3
"""Append docs scorecard generation drift summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Docs Scorecard Generation Drift\n")
    fp.write(f"- status={payload.get('status', 'unknown')}\n")
    fp.write(f"- latest_date={payload.get('latest_date', 'n/a')}\n")
    fp.write(f"- program_match={payload.get('program_match', 'n/a')}\n")
    fp.write(f"- quality_match={payload.get('quality_match', 'n/a')}\n")
