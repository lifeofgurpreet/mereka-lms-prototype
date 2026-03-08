#!/usr/bin/env python3
"""Emit catalog health fields as key=value lines for shell readarray consumption."""
import json
import sys


def _emit_list(label, items, limit=10):
    print(f"{label}={len(items)}")
    for item in items[:limit]:
        print(f"{label}_item={item}")


with open(sys.argv[1], "r", encoding="utf-8") as fp:
    summary = json.load(fp)

print(f"catalog_entries={summary['all_entries']}")
print(f"canonical_entries={summary['canonical_total']}")
print(f"canonical_stale={summary['canonical_stale']}")
print(f"canonical_missing_owner={summary['canonical_missing_owner']}")
print(f"canonical_missing_verified={summary['canonical_missing_verified']}")
print(f"canonical_high_risk={summary['canonical_high_risk']}")
print(f"canonical_missing_file={summary['canonical_missing_file']}")
_emit_list("stale_entries", summary.get("stale_entries", []))
_emit_list("canonical_missing_owner_entries", summary.get("missing_owner_entries", []))
_emit_list("canonical_missing_verified_entries", summary.get("missing_verified_entries", []))
_emit_list("canonical_missing_file_entries", summary.get("canonical_missing_file_entries", []))
