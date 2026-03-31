#!/usr/bin/env python3
"""Validate that canonical token color values appear in theme CSS/SCSS files."""
import pathlib
import re
import sys

tokens_css = open("assets/branding/tokens.css").read()
overrides = open(
    "infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
).read()
# Read the MFE manifest + all partials (WW-05 SCSS split)
mfe_scss_parts = [open("infrastructure/tutor/themes/mereka/mfe/mereka.scss").read()]
partials_dir = pathlib.Path("infrastructure/tutor/themes/mereka/mfe/scss")
if partials_dir.is_dir():
    for f in sorted(partials_dir.glob("*.scss")):
        mfe_scss_parts.append(f.read_text())
mfe_scss = "\n".join(mfe_scss_parts)

colors = dict(
    re.findall(r"(--color-(?:teal|magenta|blue|sky))\s*:\s*(#[0-9a-fA-F]{6})", tokens_css)
)
fails = []
for name, val in colors.items():
    if val.lower() not in overrides.lower():
        fails.append(f"{name}={val} missing from mereka-overrides.css")
    if val.lower() not in mfe_scss.lower():
        alias = name.replace("--color-", "--mereka-color-")
        if alias not in mfe_scss:
            fails.append(f"{name} / {alias} not referenced in mfe/mereka.scss")
if fails:
    for f in fails:
        print(f"FAIL: {f}")
    sys.exit(1)
print(f"OK: {len(colors)} key token values verified in theme files")
