#!/usr/bin/env python3
"""Append docs scorecard delta artifact summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Docs Scorecard Delta Artifact\n")
    fp.write(f"- status={payload.get('status', 'unknown')}\n")
    fp.write(f"- latest_program_date={payload.get('latest_program_date', 'n/a')}\n")
    fp.write(f"- latest_delta_date={payload.get('latest_delta_date', 'n/a')}\n")
    fp.write(f"- date_match={payload.get('date_match', 'n/a')}\n")
    fp.write(f"- has_delta_section={payload.get('has_delta_section', 'n/a')}\n")
