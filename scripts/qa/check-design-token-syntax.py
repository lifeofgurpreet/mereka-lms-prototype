#!/usr/bin/env python3
"""Validate design token syntax in assets/branding/tokens.css."""
import re
import sys

css = open("assets/branding/tokens.css").read()
if ":root" not in css:
    print("FAIL: tokens.css missing :root selector")
    sys.exit(1)
if css.count("{") != css.count("}"):
    print("FAIL: tokens.css has unbalanced braces")
    sys.exit(1)
props = re.findall(r"--[a-z0-9_-]+\s*:", css)
if len(props) < 80:
    print(f"FAIL: tokens.css only has {len(props)} properties (expected >= 80)")
    sys.exit(1)
print(f"OK: tokens.css has {len(props)} token definitions")
