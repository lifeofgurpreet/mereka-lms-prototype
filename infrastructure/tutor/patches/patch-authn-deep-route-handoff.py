#!/usr/bin/env python3
"""
Patch frontend-app-authn production bundles so relative post-login deep-route
handoffs for MFE-owned surfaces stay on the apps host instead of being rebuilt
onto LMS_BASE_URL.
"""

from __future__ import annotations

import sys
from pathlib import Path


SEARCH = "u=r&&!o.includes(r)?(0,s.zj)().LMS_BASE_URL+r:o"
REPLACEMENT = (
    "u=r&&!o.includes(r)?"
    "(/^\\/(?:authn|account|course-authoring|authoring|communications|discussions|"
    "gradebook|learner-dashboard|learner-record|learning|ora-grading|profile|u)"
    "(?:\\/|$)/.test(r)?window.location.origin+r:(0,s.zj)().LMS_BASE_URL+r):o"
)


def patch_dist(dist_dir: Path) -> int:
    total_matches = 0
    for js_file in sorted(dist_dir.glob("*.js")):
        if js_file.name == "env.config.js":
            continue
        text = js_file.read_text(encoding="utf-8")
        count = text.count(SEARCH)
        if not count:
            continue
        js_file.write_text(text.replace(SEARCH, REPLACEMENT), encoding="utf-8")
        total_matches += count
    return total_matches


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: patch-authn-deep-route-handoff.py <dist_dir>", file=sys.stderr)
        return 2

    dist_dir = Path(argv[1])
    if not dist_dir.is_dir():
        print(f"dist dir not found: {dist_dir}", file=sys.stderr)
        return 2

    matches = patch_dist(dist_dir)
    if matches == 0:
        print("expected authn deep-route handoff signature missing", file=sys.stderr)
        return 1

    print(f"patched authn deep-route handoff signature ({matches} occurrence(s))")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
