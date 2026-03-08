#!/usr/bin/env python3
"""Fail if changed transitional-root docs are not stub-only superseded pointers."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

TRANSITIONAL_PREFIXES = (
    "docs/operations/",
    "docs/onboarding/",
    "docs/branding/",
    "docs/runbooks/",
    "docs/architecture/",
)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", default=".")
    p.add_argument("--range", default="HEAD~1...HEAD")
    p.add_argument("--summary-file", default="")
    p.add_argument("paths", nargs="*")
    return p.parse_args()


def changed_paths(repo_root: Path, diff_range: str) -> list[str]:
    result = subprocess.run(
        [
            "git",
            "diff",
            "--name-only",
            diff_range,
            "--",
            "docs/operations/**",
            "docs/onboarding/**",
            "docs/branding/**",
            "docs/runbooks/**",
            "docs/architecture/**",
        ],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def is_transitional(path: str) -> bool:
    normalized = path.replace("\\", "/")
    if not normalized.endswith(".md"):
        return False
    if normalized.startswith(TRANSITIONAL_PREFIXES):
        return True
    return any(f"/{prefix}" in normalized for prefix in TRANSITIONAL_PREFIXES)


def check_stub(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    head = "\n".join(text.splitlines()[:25])
    errors: list[str] = []
    if not re.search(r"status:\s*\"?superseded\"?|Status:\s*superseded", head, flags=re.IGNORECASE):
        errors.append(f"{path}: transitional doc must be marked superseded")
    if not re.search(r"(?im)^\s*superseded_by:\s*.+$", text):
        errors.append(f"{path}: transitional doc missing superseded_by pointer")
    return errors


def main() -> int:
    args = parse_args()
    repo_root = Path(args.root).resolve()
    rel_paths = args.paths or changed_paths(repo_root, args.range)
    files_checked = 0
    errors: list[str] = []

    for rel in rel_paths:
        if not is_transitional(rel):
            continue
        full = repo_root / rel
        if not full.exists():
            continue
        files_checked += 1
        errors.extend(check_stub(full))

    summary = {
        "status": "fail" if errors else "pass",
        "range": args.range,
        "files_checked": files_checked,
        "errors": errors,
    }
    if args.summary_file:
        Path(args.summary_file).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    if errors:
        print("TRANSITIONAL_STUB_ERRORS")
        for item in errors:
            print(f"- {item}")
        return 1

    print(f"TRANSITIONAL_STUB_OK files_checked={files_checked}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
