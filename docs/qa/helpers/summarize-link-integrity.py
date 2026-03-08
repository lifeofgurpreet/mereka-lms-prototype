#!/usr/bin/env python3
"""Append docs link integrity summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Docs Link Integrity\n")
    fp.write(f"- status={payload.get('status', 'unknown')}\n")
    fp.write(f"- files_checked={payload.get('files_checked', 'n/a')}\n")
    fp.write(f"- broken_links={payload.get('broken_links', 'n/a')}\n")
