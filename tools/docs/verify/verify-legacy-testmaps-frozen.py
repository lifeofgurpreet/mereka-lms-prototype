#!/usr/bin/env python3
"""Fail if a diff edits frozen legacy testmaps under specs/testmaps/."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ALLOWED_LEGACY_PATHS = {
    "specs/testmaps/README.md",
    "specs/testmaps/RETIREMENT_PLAN.md",
}


def _ref_exists(ref: str, repo_root: Path) -> bool:
    """Check whether a git ref is resolvable."""
    return subprocess.run(
        ["git", "rev-parse", "--verify", ref],
        cwd=repo_root,
        capture_output=True,
        check=False,
    ).returncode == 0


def git_changed_files(repo_root: Path, diff_range: str) -> list[str] | None:
    """Return changed files in range, or None if the range is unresolvable."""
    # Verify refs before running diff — avoids hard failure on shallow clones
    # or workflow_dispatch where origin/main may not exist.
    for ref in diff_range.replace("...", " ").replace("..", " ").split():
        if ref and not _ref_exists(ref, repo_root):
            return None

    result = subprocess.run(
        ["git", "diff", "--name-only", diff_range, "--", "specs/testmaps/**", "specs/testmaps/*"],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git diff failed for range {diff_range}")
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def main() -> int:
    ap = argparse.ArgumentParser(description="Block edits to frozen legacy specs/testmaps/**")
    ap.add_argument("--range", required=True, dest="diff_range", help="git diff range to inspect")
    ap.add_argument("--summary-file", help="optional JSON summary path")
    args = ap.parse_args()

    repo_root = Path.cwd()
    raw = git_changed_files(repo_root, args.diff_range)

    if raw is None:
        # Refs not available (shallow clone, workflow_dispatch, etc.) — skip gracefully
        print(f"LEGACY_TESTMAP_FREEZE_SKIP range={args.diff_range} reason=unresolvable_ref")
        summary = {
            "status": "skip",
            "range": args.diff_range,
            "reason": "One or more refs in the range are unresolvable (shallow clone?)",
        }
        if args.summary_file:
            Path(args.summary_file).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        return 0

    changed_files = [
        path
        for path in raw
        if path not in ALLOWED_LEGACY_PATHS
    ]
    summary = {
        "status": "pass" if not changed_files else "fail",
        "range": args.diff_range,
        "frozen_root": "specs/testmaps/**",
        "allowed_paths": sorted(ALLOWED_LEGACY_PATHS),
        "changed_files": changed_files,
        "changed_count": len(changed_files),
    }

    if args.summary_file:
        Path(args.summary_file).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    if changed_files:
        print(
            f"LEGACY_TESTMAP_FREEZE_FAIL range={args.diff_range} changed_count={len(changed_files)}",
            file=sys.stderr,
        )
        for path in changed_files:
            print(path, file=sys.stderr)
        return 1

    print(f"LEGACY_TESTMAP_FREEZE_OK range={args.diff_range} changed_count=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
