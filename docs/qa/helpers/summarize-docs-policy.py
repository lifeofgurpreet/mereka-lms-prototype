#!/usr/bin/env python3
"""Append docs policy summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    payload = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Docs Policy\n")
    fp.write(f"- status={payload.get('status', 'unknown')}\n")
    fp.write(f"- range={payload.get('range', 'n/a')}\n")
    fp.write(f"- root_allowlist_violations={payload.get('root_allowlist_violations', 0)}\n")
    fp.write(f"- changed_markdown_files={payload.get('changed_markdown_files', 0)}\n")
    fp.write(f"- content_status={payload.get('content_status', 'unknown')}\n")
    fp.write(f"- content_files_checked={payload.get('content_files_checked', 0)}\n")
    fp.write(f"- content_errors={len(payload.get('content_errors', []))}\n")
