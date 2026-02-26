#!/usr/bin/env python3
"""Validate MFE messages.json files: check valid JSON and no broken format strings."""
import json
import re
import subprocess
import sys

result = subprocess.run(
    ["find", "infrastructure/tutor/themes/mereka/mfe", "-name", "messages.json"],
    capture_output=True,
    text=True,
)
json_files = [f for f in result.stdout.strip().splitlines() if f]

if not json_files:
    print("SKIP: No messages.json files found (MFE locales not yet pulled)")
    sys.exit(0)

fail_count = 0
for json_path in json_files:
    try:
        with open(json_path) as f:
            content = f.read()
        json.loads(content)
        broken = re.findall(r"%\([^)]*$", content)
        if broken:
            print(f"FAIL: {json_path} has broken format string(s)")
            fail_count += 1
        else:
            print(f"PASS: {json_path}")
    except json.JSONDecodeError as e:
        print(f"FAIL: {json_path} is not valid JSON: {e}")
        fail_count += 1

if fail_count > 0:
    sys.exit(1)
