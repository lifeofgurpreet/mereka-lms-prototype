#!/usr/bin/env python3
"""Append docs catalog governance summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Docs Catalog Governance\n")
    fp.write(f"- status={payload.get('status', 'unknown')}\n")
    fp.write(
        f"- changed_docs_checked={payload.get('changed_docs_checked', 'n/a')}\n"
    )
    fp.write(
        "- duplicate_groups="
        f"{len(payload.get('duplicate_canonical_groups', {}))}\n"
    )
    fp.write(
        "- uncovered_changed_docs="
        f"{len(payload.get('uncovered_changed_docs', []))}\n"
    )
