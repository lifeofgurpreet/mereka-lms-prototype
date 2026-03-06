#!/usr/bin/env python3
"""Validate Markdown local link integrity for docs files."""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path
from typing import Iterable


LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
REPO_ROOT = Path(__file__).resolve().parents[2]
DOCS_DIR = REPO_ROOT / "docs"


def list_changed_files() -> list[Path]:
    result = subprocess.run(
        ["git", "diff", "--name-only", "origin/main...HEAD", "--", "docs/**/*.md", "docs/*.md"],
        capture_output=True,
        text=True,
        check=True,
    )
    return [REPO_ROOT / Path(line.strip()) for line in result.stdout.splitlines() if line.strip()]


def resolve_link(source_path: Path, raw: str) -> Path:
    link = raw.split("#", 1)[0].split("?", 1)[0].strip()
    if not link:
        return source_path

    if "://" in link or link.startswith(("mailto:", "tel:", "#")):
        return source_path

    if link.startswith("/"):
        link = link.lstrip("/")

    if link.startswith("docs/"):
        target = REPO_ROOT / link
    else:
        target = (source_path.parent / link).resolve()

    return target


def collect_markdown_files(raw_files: Iterable[str]) -> list[Path]:
    files: list[Path] = []
    for name in raw_files:
        p = DOCS_DIR / Path(name) if not name.startswith("docs/") else REPO_ROOT / Path(name)
        if p.exists():
            files.append(p)
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="*", help="Optional explicit list of docs files")
    args = parser.parse_args()

    if args.files:
        files = collect_markdown_files(args.files)
    else:
        files = [Path(p) for p in list_changed_files()]

    if not files:
        print("DOCS_LINK_INTEGRITY_OK (0 files, 0 broken links)")
        return 0

    broken: list[str] = []
    for path in sorted(files):
        if not path.exists() or path.suffix.lower() != ".md":
            continue

        rel = path.relative_to(REPO_ROOT)
        text = path.read_text(encoding="utf-8", errors="replace")
        for raw in LINK_RE.findall(text):
            raw = raw.strip()
            if raw.startswith(("http://", "https://", "mailto:", "tel:", "#")):
                continue

            target = resolve_link(path, raw)
            if target.exists():
                continue
            if not str(target).startswith(str(DOCS_DIR)):
                continue

            # strip fragment for directory links like docs/ and anchors only
            broken.append(f"{rel}: {raw}")

    if broken:
        print(f"DOCS_LINK_INTEGRITY_ERRORS ({len(broken)} missing)")
        for item in broken:
            print(f"- {item}")
        return 1

    print(f"DOCS_LINK_INTEGRITY_OK ({len(files)} files, 0 broken links)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
