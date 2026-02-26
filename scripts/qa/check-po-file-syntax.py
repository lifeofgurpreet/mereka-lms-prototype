#!/usr/bin/env python3
"""Validate .po file syntax: check UTF-8 encoding and presence of msgid/msgstr pairs."""
import subprocess
import sys

result = subprocess.run(
    ["find", "tutor_env/env/build/openedx/locale", "-name", "*.po"],
    capture_output=True,
    text=True,
)
po_files = [f for f in result.stdout.strip().splitlines() if f]

if not po_files:
    print("SKIP: No .po files found (locale directory not in repo — expected)")
    sys.exit(0)

fail_count = 0
for po in po_files:
    try:
        with open(po, encoding="utf-8") as f:
            content = f.read()
        if "msgid" not in content or "msgstr" not in content:
            print(f"FAIL: {po} missing msgid/msgstr pairs")
            fail_count += 1
        else:
            print(f"PASS: {po}")
    except UnicodeDecodeError as e:
        print(f"FAIL: {po} is not valid UTF-8: {e}")
        fail_count += 1

if fail_count > 0:
    sys.exit(1)
