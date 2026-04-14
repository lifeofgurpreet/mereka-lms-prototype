#!/usr/bin/env python3
"""
Verify compiled frontend-app-authn assets no longer rebuild dashboard fallbacks
onto LMS_BASE_URL after the source patch and dist handoff patch run.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


FORBIDDEN_PATTERNS = (
    re.compile(r"LMS_BASE_URL[^\\n\"']{0,80}/dashboard"),
    re.compile(r"LMS_BASE_URL[^\\n\"']{0,120}dashboard/\\?tpa_hint"),
)
REQUIRED_MARKER = "window.location.origin+r"


def verify_dist(dist_dir: Path) -> tuple[list[str], bool]:
    offenders: list[str] = []
    saw_required_marker = False

    for asset in sorted(dist_dir.rglob("*")):
        if asset.suffix not in {".js", ".map"}:
            continue
        try:
            content = asset.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue

        if REQUIRED_MARKER in content:
            saw_required_marker = True
        if any(pattern.search(content) for pattern in FORBIDDEN_PATTERNS):
            offenders.append(str(asset))

    return offenders, saw_required_marker


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: verify-authn-dashboard-fallbacks.py <dist_dir>", file=sys.stderr)
        return 2

    dist_dir = Path(argv[1])
    if not dist_dir.is_dir():
        print(f"dist dir not found: {dist_dir}", file=sys.stderr)
        return 2

    offenders, saw_required_marker = verify_dist(dist_dir)
    if offenders:
        print(
            "authn dashboard fallback guard failed in " + ", ".join(offenders),
            file=sys.stderr,
        )
        return 1
    if not saw_required_marker:
        print("authn deep-route handoff patch marker missing from dist assets", file=sys.stderr)
        return 1

    print("verified authn dashboard fallbacks in compiled assets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
