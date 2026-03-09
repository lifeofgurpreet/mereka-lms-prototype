#!/usr/bin/env python3
"""Report non-stub markdown files that remain under losing documentation roots."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

TRANSITIONAL_ROOTS = (
    "docs/operations",
    "docs/architecture",
    "docs/runbooks",
    "docs/onboarding",
    "docs/branding",
)

STATUS_MARKERS = (
    "Status: superseded",
    "Status: archive-candidate",
)

REDIRECT_MARKERS = (
    "superseded_by:",
    "Superseded by:",
    "This path is transitional only.",
    "This document has moved to:",
    "This legacy tree has moved to:",
    "Canonical replacement",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--summary-file", default="")
    parser.add_argument("--limit", type=int, default=50)
    parser.add_argument("--fail-on-nonstub", action="store_true")
    return parser.parse_args()


def is_stub(path: Path) -> bool:
    text = path.read_text(encoding="utf-8", errors="ignore")
    head = text[:4000]
    return any(marker in head for marker in STATUS_MARKERS) and any(
        marker in head for marker in REDIRECT_MARKERS
    )


def collect_root_status(repo_root: Path, rel_root: str, limit: int) -> dict[str, object]:
    root = repo_root / rel_root
    markdown_files = sorted(
        p for p in root.rglob("*.md") if p.is_file()
    )
    stub_files: list[str] = []
    nonstub_files: list[str] = []
    for path in markdown_files:
        rel_path = path.relative_to(repo_root).as_posix()
        if is_stub(path):
            stub_files.append(rel_path)
        else:
            nonstub_files.append(rel_path)

    return {
        "root": rel_root,
        "exists": root.exists(),
        "markdown_files_count": len(markdown_files),
        "stub_files_count": len(stub_files),
        "nonstub_files_count": len(nonstub_files),
        "nonstub_files_sample": nonstub_files[:limit],
    }


def main() -> int:
    args = parse_args()
    repo_root = Path(args.root).resolve()

    roots = [
        collect_root_status(repo_root, rel_root, args.limit)
        for rel_root in TRANSITIONAL_ROOTS
    ]
    total_nonstub = sum(int(root["nonstub_files_count"]) for root in roots)
    summary = {
        "status": "fail" if total_nonstub and args.fail_on_nonstub else "advisory",
        "transitional_roots": roots,
        "total_nonstub_files_count": total_nonstub,
    }

    if args.summary_file:
        Path(args.summary_file).write_text(
            json.dumps(summary, indent=2) + "\n",
            encoding="utf-8",
        )

    label = (
        "NONSTUB_TRANSITIONAL_FILES_FAIL"
        if total_nonstub and args.fail_on_nonstub
        else "NONSTUB_TRANSITIONAL_FILES_ADVISORY"
    )
    print(f"{label} total_nonstub_files={total_nonstub}")
    for root in roots:
        print(
            f"{root['root']}: "
            f"markdown_files={root['markdown_files_count']} "
            f"stub_files={root['stub_files_count']} "
            f"nonstub_files={root['nonstub_files_count']}"
        )

    return 1 if total_nonstub and args.fail_on_nonstub else 0


if __name__ == "__main__":
    raise SystemExit(main())
