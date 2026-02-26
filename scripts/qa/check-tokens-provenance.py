#!/usr/bin/env python3
"""Validate tokens.provenance.json has required fields and correct SHA formats."""
import json
import re
import sys

p = json.load(open("assets/branding/tokens.provenance.json"))
required = [
    "source_repo",
    "source_path",
    "source_branch",
    "source_commit",
    "source_sha256",
    "synced_at_utc",
]
missing = [k for k in required if not p.get(k)]
if missing:
    print(f"FAIL: provenance missing keys: {missing}")
    sys.exit(1)
if not re.fullmatch(r"[0-9a-f]{40}", p["source_commit"]):
    print("FAIL: source_commit is not a valid 40-char SHA")
    sys.exit(1)
if not re.fullmatch(r"[0-9a-f]{64}", p["source_sha256"]):
    print("FAIL: source_sha256 is not a valid 64-char SHA256")
    sys.exit(1)
print("OK: tokens.provenance.json is valid")
