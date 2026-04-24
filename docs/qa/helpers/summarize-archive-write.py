#!/usr/bin/env python3
"""Append archive write protection summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Archive Write Protection\n")
    fp.write(f"- status={payload.get('status', 'unknown')}\n")
    fp.write(
        f"- authorized={str(payload.get('authorized', False)).lower()}\n"
    )
    fp.write(
        f"- archive_changes={len(payload.get('archive_changes', []))}\n"
    )
