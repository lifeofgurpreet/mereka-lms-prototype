#!/usr/bin/env python3
"""Append docs foundation gates summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Docs Foundation Gates\n")
    fp.write(f"- status={payload.get('status', 'unknown')}\n")
    fp.write(f"- policy_status={payload.get('policy_status', 'unknown')}\n")
    fp.write(f"- repo_structure_status={payload.get('repo_structure_status', 'unknown')}\n")
    fp.write(f"- policy_range={payload.get('policy_range', 'n/a')}\n")
    fp.write(f"- policy_root_allowlist_violations={payload.get('policy_root_allowlist_violations', 0)}\n")
    fp.write(f"- policy_changed_markdown_files={payload.get('policy_changed_markdown_files', 0)}\n")
    fp.write(f"- policy_content_status={payload.get('policy_content_status', 'unknown')}\n")
    fp.write(f"- policy_content_consistent={str(payload.get('policy_content_consistent', 'n/a')).lower()}\n")
    fp.write(f"- policy_content_errors={len(payload.get('policy_content_errors', []))}\n")
