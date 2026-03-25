#!/usr/bin/env python3
"""Append docs catalog residue summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Docs Catalog Residue (Advisory)\n")
    fp.write(
        "- uncataloged_winning_docs="
        f"{payload.get('uncataloged_winning_docs_count', 'n/a')}\n"
    )
    fp.write(
        "- stale_catalog_entries="
        f"{payload.get('stale_catalog_entries_count', 'n/a')}\n"
    )
    fp.write(
        "- duplicate_canonical_groups="
        f"{payload.get('duplicate_canonical_groups_count', 'n/a')}\n"
    )
