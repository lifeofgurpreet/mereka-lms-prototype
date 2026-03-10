#!/usr/bin/env python3
"""Compatibility wrapper for the frontmatter-driven ADR ledger builder."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    result = subprocess.run(
        [sys.executable, "tools/docs/build_adr_ledger.py"],
        cwd=root,
    )
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
