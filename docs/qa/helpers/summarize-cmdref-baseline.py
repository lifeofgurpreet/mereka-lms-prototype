#!/usr/bin/env python3
"""Append docs command reference baseline summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Docs Command Reference Baseline\n")
    fp.write(f"- status={payload.get('status', 'unknown')}\n")
    fp.write(f"- entries={payload.get('entries', 'n/a')}\n")
    fp.write(f"- duplicates={len(payload.get('duplicates', []))}\n")
    fp.write(f"- missing={len(payload.get('missing', []))}\n")
    fp.write(f"- invalid_non_markdown={len(payload.get('invalid_non_markdown', []))}\n")
