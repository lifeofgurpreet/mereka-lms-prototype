#!/usr/bin/env python3
"""Append legacy testmap freeze summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Legacy Testmap Freeze\n")
    fp.write(f"- status={payload.get('status', 'unknown')}\n")
    fp.write(f"- changed_count={payload.get('changed_count', 'n/a')}\n")
    fp.write(f"- frozen_root={payload.get('frozen_root', 'n/a')}\n")
