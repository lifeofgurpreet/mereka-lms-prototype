#!/usr/bin/env python3
"""Append non-stub transitional root summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Transitional Roots Non-Stub Inventory\n")
    fp.write(
        "- total_nonstub_files="
        f"{payload.get('total_nonstub_files_count', 'n/a')}\n"
    )
    for root in payload.get("transitional_roots", []):
        fp.write(
            f"- {root.get('root')}: "
            f"nonstub_files={root.get('nonstub_files_count', 'n/a')} "
            f"stub_files={root.get('stub_files_count', 'n/a')}\n"
        )
