#!/usr/bin/env python3
"""Append docs orphan scan summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Docs Orphan Scan\n")
    fp.write(
        f"- candidates_checked={payload.get('candidates_checked', 'n/a')}\n"
    )
    fp.write(
        f"- orphan_docs={payload.get('orphan_docs_count', 'n/a')}\n"
    )
