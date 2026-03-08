#!/usr/bin/env python3
"""Append docs command reference summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

missing = payload.get("missing", [])

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Docs Command Reference Summary\n")
    fp.write(f"- files_checked={payload.get('files_checked', 0)}\n")
    fp.write(f"- total_candidates={payload.get('total_candidates', 0)}\n")
    fp.write(f"- missing_references={payload.get('missing_references', 0)}\n")
    fp.write(f"- status={payload.get('status')}\n")
    for item in missing[:15]:
        fp.write(f"- {item}\n")
