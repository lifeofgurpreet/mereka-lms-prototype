#!/usr/bin/env python3
"""Enforce winning-root structure for active evidence and status docs."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

WINNING_EVIDENCE_ROOT = "docs/evidence/"
WINNING_STATUS_ROOT = "docs/status/"
ALLOWED_STATUS_PREFIXES = (
    "docs/status/active/",
    "docs/status/incidents/",
    "docs/status/migrations/",
    "docs/status/readiness/",
    "docs/status/weekly/",
)
LOSING_EVIDENCE_PREFIXES = (
    "evidence/",
    "docs/archive/evidence/",
)
LOSING_STATUS_PREFIXES = (
    "reports/2026/status/",
    "reports/2026/readiness/",
    "docs/archive/reports/",
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
            "docs/evidence/**",
            "docs/status/**",
            "evidence/**",
            "reports/2026/status/**",
            "reports/2026/readiness/**",
            "docs/archive/evidence/**",
            "docs/archive/reports/**",
        ],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def is_stub(text: str) -> bool:
    head = "\n".join(text.splitlines()[:25])
    return bool(
        re.search(r"status:\s*\"?superseded\"?|Status:\s*superseded", head, flags=re.IGNORECASE)
        and re.search(r"(?im)^\s*superseded_by:\s*.+$", text)
    )


def main() -> int:
    args = parse_args()
    repo_root = Path(args.root).resolve()
    rel_paths = args.paths or changed_paths(repo_root, args.range)
    errors: list[str] = []
    evidence_checked = 0
    status_checked = 0
    losing_checked = 0

    for rel in rel_paths:
        normalized = rel.replace("\\", "/")
        full = repo_root / rel
        if not full.exists() or not full.is_file():
            continue

        if normalized == "docs/evidence/INDEX.md":
            evidence_checked += 1
            continue

        if normalized.startswith(WINNING_EVIDENCE_ROOT):
            evidence_checked += 1
            if not normalized.endswith(".md"):
                errors.append(f"{rel}: active evidence docs must be markdown")
            elif normalized.count("/") < 3:
                errors.append(f"{rel}: active evidence docs must live under docs/evidence/<domain>/")
            continue

        if normalized == "docs/status/INDEX.md":
            status_checked += 1
            continue

        if normalized.startswith(WINNING_STATUS_ROOT):
            status_checked += 1
            if not normalized.endswith(".md"):
                errors.append(f"{rel}: active status docs must be markdown")
            elif not normalized.startswith(ALLOWED_STATUS_PREFIXES):
                errors.append(
                    f"{rel}: active status docs must live under docs/status/active, docs/status/incidents, docs/status/migrations, docs/status/readiness, or docs/status/weekly"
                )
            continue

        if normalized.startswith(LOSING_EVIDENCE_PREFIXES) or normalized.startswith(LOSING_STATUS_PREFIXES):
            losing_checked += 1
            if normalized.endswith(".md"):
                text = full.read_text(encoding="utf-8", errors="ignore")
                if not is_stub(text):
                    errors.append(f"{rel}: losing-root markdown doc must remain a superseded stub")
            else:
                errors.append(f"{rel}: losing-root non-markdown file must not be changed")

    summary = {
        "status": "fail" if errors else "pass",
        "range": args.range,
        "evidence_checked": evidence_checked,
        "status_checked": status_checked,
        "losing_checked": losing_checked,
        "errors": errors,
    }
    if args.summary_file:
        Path(args.summary_file).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    if errors:
        print("EVIDENCE_STATUS_ROOT_POLICY_FAIL")
        for item in errors:
            print(f"- {item}")
        return 1

    print(
        "EVIDENCE_STATUS_ROOT_POLICY_OK "
        f"evidence_checked={evidence_checked} status_checked={status_checked} losing_checked={losing_checked}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
