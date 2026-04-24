#!/usr/bin/env python3
"""Fail if docs/archive changes are introduced without explicit authorization."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path

ARCHIVE_PREFIX = "docs/archive/"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", default=".")
    p.add_argument("--range", default="HEAD~1...HEAD")
    p.add_argument("--allow-env-var", default="DOCS_ALLOW_ARCHIVE_WRITES")
    p.add_argument("--summary-file", default="")
    p.add_argument("paths", nargs="*")
    return p.parse_args()


def changed_paths(repo_root: Path, diff_range: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", diff_range, "--", "docs/archive/**"],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def main() -> int:
    args = parse_args()
    repo_root = Path(args.root).resolve()
    allow_value = os.environ.get(args.allow_env_var, "").strip().lower()
    allowed = allow_value in {"1", "true", "yes"}
    rel_paths = args.paths or changed_paths(repo_root, args.range)
    archive_changes = [
        p for p in rel_paths
        if p.startswith(ARCHIVE_PREFIX) or f"/{ARCHIVE_PREFIX}" in p.replace("\\", "/")
    ]

    summary = {
        "status": "pass",
        "range": args.range,
        "allow_env_var": args.allow_env_var,
        "authorized": allowed,
        "archive_changes": archive_changes,
    }

    if archive_changes and not allowed:
        summary["status"] = "fail"

    if args.summary_file:
        Path(args.summary_file).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    if archive_changes and not allowed:
        print(f"ARCHIVE_WRITE_PROTECTION_FAIL env={args.allow_env_var}")
        for path in archive_changes:
            print(f"- {path}")
        return 1

    if archive_changes:
        print(f"ARCHIVE_WRITE_PROTECTION_AUTHORIZED env={args.allow_env_var} files={len(archive_changes)}")
    else:
        print("ARCHIVE_WRITE_PROTECTION_OK files=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
