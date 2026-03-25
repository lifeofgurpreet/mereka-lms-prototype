#!/usr/bin/env python3
"""Append evidence/status root summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Evidence and Status Root Policy\n")
    fp.write(f"- status={payload.get('status', 'unknown')}\n")
    fp.write(
        f"- evidence_checked={payload.get('evidence_checked', 'n/a')}\n"
    )
    fp.write(f"- status_checked={payload.get('status_checked', 'n/a')}\n")
    fp.write(f"- losing_checked={payload.get('losing_checked', 'n/a')}\n")
    fp.write(f"- errors={len(payload.get('errors', []))}\n")
