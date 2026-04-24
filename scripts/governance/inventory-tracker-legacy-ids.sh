#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-.}"
jsonl="${repo_root%/}/.beads/issues.jsonl"

if [[ ! -f "$jsonl" ]]; then
  echo "error: missing tracker JSONL at $jsonl" >&2
  exit 2
fi

python3 - "$jsonl" <<'PY'
import json
import re
import sys
from collections import Counter

jsonl = sys.argv[1]
bad_pat = re.compile(r"^(bd-|mereka-(?!lms))")

rows = []
status_counts = Counter()
kind_counts = Counter()

with open(jsonl, "r", encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        obj = json.loads(line)
        iid = obj.get("id", "")
        if not bad_pat.match(iid):
            continue
        status = obj.get("status", "")
        typ = obj.get("type", "")
        title = obj.get("title", "")
        rows.append((iid, status, typ, title))
        status_counts[status or "<empty>"] += 1
        kind_counts[typ or "<empty>"] += 1

print("=== Tracker Legacy ID Inventory ===")
print(f"jsonl: {jsonl}")
print(f"legacy_count: {len(rows)}")
print("status_counts:")
for key, value in sorted(status_counts.items()):
    print(f"  {key}: {value}")
print("type_counts:")
for key, value in sorted(kind_counts.items()):
    print(f"  {key}: {value}")
print("--- rows ---")
for iid, status, typ, title in rows:
    print(f"{iid}|{status}|{typ}|{title}")
PY
