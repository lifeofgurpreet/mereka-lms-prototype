#!/usr/bin/env python3
"""mereka_spec_verify.py — Project-specific spec verifier for Mereka LMS.

Uses @covers annotations in source files as the source of truth.
Manual/monitoring entries come from specs/manual_verifications.yaml.

Adapts the generic spec_verify.py for our directory layout.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from spec_verify import (
    find_markdown_files,
    verify_one_spec,
)


def main() -> int:
    ap = argparse.ArgumentParser(description="Verify Mereka LMS specs via @covers annotations.")
    ap.add_argument("path", type=str, help="Spec file or specs/ directory")
    ap.add_argument("--repo-root", type=str, default=".", help="Repo root for resolving paths")
    ap.add_argument(
        "--scan-dirs",
        nargs="+",
        default=["scripts/", "tests/"],
        help="Directories to scan for @covers annotations",
    )
    ap.add_argument(
        "--manual-file",
        type=str,
        default="specs/manual_verifications.yaml",
        help="Path to manual_verifications.yaml",
    )
    ap.add_argument("--run", action="store_true", help="Execute verification commands")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    target = Path(args.path)
    if not target.exists():
        print(f"ERROR: path not found: {target}")
        return 2

    scan_dirs = [repo_root / d for d in args.scan_dirs]
    manual_file = Path(args.manual_file) if args.manual_file else None
    if manual_file and not manual_file.is_absolute():
        manual_file = repo_root / manual_file

    files = find_markdown_files(target)
    spec_files = [f for f in files if f.name.endswith("_spec.md")]

    if not spec_files:
        print("No *_spec.md files found.")
        return 0

    any_errors = False
    for f in spec_files:
        errs = verify_one_spec(f, scan_dirs, manual_file, args.run, repo_root)
        if errs:
            any_errors = True
            print(f"\nFAIL {f}")
            for e in errs:
                print(f"  - {e}")
        else:
            print(f"PASS {f}")

    return 1 if any_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
